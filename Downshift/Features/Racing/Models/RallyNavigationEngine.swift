//
//  RallyNavigationEngine.swift
//  Downshift
//
//  Converts raw GPS route coordinates into rally pace-note instructions using the
//  full cubic-spline + 3-D curvature pipeline described in RALLY_NAVIGATION_TECHNICAL_DOCUMENT.md.
//
//  Pipeline:
//    1. Adaptive polyline refinement   (3.5 m near sharp corners, 150 m on straights)
//    2. Midpoint smoothing pass
//    3. Cubic spline fit through refined points
//    4. Sample at constant delta (5 m) + compute signed 3-D curvature
//    5. Classify each sample by curvature threshold → rank -1..8
//    6. Build initial curves (group consecutive same-rank, same-orientation samples)
//    7. Find local-maxima curves
//    8. Remove overlap, join curves, stick broken curves (×2)
//    9. Hairpin / square reclassification
//   10. Apply length modifiers (short / long / extra-long)
//   11. Return detected curves ready for TurnInstruction emission

import Foundation
import CoreLocation

// MARK: - GeoPoint

struct GeoPoint {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coord: CLLocationCoordinate2D) {
        self.latitude = coord.latitude
        self.longitude = coord.longitude
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - CurveType

struct RallyCurveType: Equatable {
    let name: String
    let curvatureRadius: Double  // metres
    let minLength: Double
    let rank: Int
    let shortLength: Double
    let longLength: Double

    var curvatureThreshold: Double { 1.0 / curvatureRadius }

    static let defaults: [RallyCurveType] = [
        RallyCurveType(name: "six",     curvatureRadius: 1000, minLength: 50,  rank: 1, shortLength: 100, longLength: 350),
        RallyCurveType(name: "five",    curvatureRadius:  500, minLength: 25,  rank: 2, shortLength:  75, longLength: 275),
        RallyCurveType(name: "four",    curvatureRadius:  250, minLength: 15,  rank: 3, shortLength:  50, longLength: 225),
        RallyCurveType(name: "three",   curvatureRadius:  125, minLength: 10,  rank: 4, shortLength:  35, longLength: 175),
        RallyCurveType(name: "two",     curvatureRadius:   50, minLength:  7,  rank: 5, shortLength:  20, longLength: 150),
        RallyCurveType(name: "one",     curvatureRadius:   25, minLength:  6,  rank: 6, shortLength:  15, longLength: 100),
        RallyCurveType(name: "square",  curvatureRadius:   20, minLength:  5,  rank: 7, shortLength: 100, longLength: 250),
        RallyCurveType(name: "hairpin", curvatureRadius:   10, minLength: 10,  rank: 8, shortLength: 100, longLength: 250),
    ]
}

// MARK: - RoutePoint (spline-sampled)

struct SplineRoutePoint {
    let progress: Double        // cumulative distance from start (metres)
    let coords: GeoPoint
    let curvature: Double       // signed curvature (1/m)
    var rank: Int               // -1 = straight, 1–8 = curve rank
    var orientation: Bool       // true = right, false = left
}

// MARK: - RallyCurve

struct RallyCurve {
    let typeName: String
    let rank: Int
    let startIndex: Int
    let endIndex: Int
    let start: Double           // progress at start (metres)
    let end: Double             // progress at end (metres)
    let orientation: Bool       // true = right, false = left
    var isShort: Bool = false
    var isLong: Bool = false
    var isExtraLong: Bool = false

    var length: Double { end - start }
}

// MARK: - Constants

private enum NavConstants {
    static let delta: Double = 5.0               // sampling interval (m)
    static let angleThreshold: Double = 9.0      // degrees, minimum angle to keep
    static let hairpinAngleThreshold: Double = 150.0
    static let squareLower: Double = 75.0
    static let squareUpper: Double = 115.0
    static let squareMaxLength: Double = 20.0
    /// Max gap between adjacent curve fragments that should be joined into one curve.
    static let maxDistJoin: Double = 50.0
    /// Max gap for stick-broken-curves pass (fragments of the same real-world corner).
    static let maxDistStick: Double = 100.0
    /// Minimum curve length to keep after all merging (m). Shorter ones are noise.
    static let minCurveLength: Double = 15.0
    static let earthRadius: Double = 6_378_137.0 // WGS-84 semi-major axis
}

// MARK: - RallyNavigationEngine

enum RallyNavigationEngine {

    // MARK: - Public entry point

    /// Full pipeline: GPS coords → detected rally curves.
    static func detectCurves(from rawCoords: [CLLocationCoordinate2D]) -> [RallyCurve] {
        guard rawCoords.count >= 2 else { return [] }

        let rawPoints = rawCoords.map { GeoPoint($0) }

        // Step 1 & 2: refine + smooth
        let refined = refinePolyline(rawPoints)
        guard refined.count >= 4 else { return [] }

        // Step 3: fit cubic spline
        guard let spline = Spline(points: refined) else { return [] }

        // Step 4: sample at delta intervals
        let routePoints = sampleRoutePoints(spline: spline)
        guard routePoints.count >= 3 else { return [] }

        // Step 6: build initial curves
        var curves = buildCurves(routePoints: routePoints)

        // Step 7: local maxima filter
        curves = findLocalMaximaCurves(curves)

        // Step 8: post-processing
        curves = removeOverlap(curves)
        curves = joinCurves(curves)
        curves = stickBrokenCurves(curves)
        curves = stickBrokenCurves(curves)
        curves = removeShortCurves(curves)

        // Step 9: hairpin / square reclassification
        curves = findHairpins(curves: curves, routePoints: routePoints)

        // Step 10: length modifiers
        curves = curves.map { applyModifiers($0) }

        return curves
    }

    // MARK: - Step 1 & 2: Polyline refinement + smoothing

    private static func refinePolyline(_ raw: [GeoPoint]) -> [GeoPoint] {
        var refined: [GeoPoint] = []

        for i in 0..<(raw.count - 1) {
            var dotBefore: Double = 1.0
            var dotAfter:  Double = 1.0

            if i > 0 {
                let d1 = direction(from: raw[i - 1], to: raw[i])
                let d2 = direction(from: raw[i],     to: raw[i + 1])
                dotBefore = dot(d1, d2)
            }
            if i < raw.count - 2 {
                let d1 = direction(from: raw[i],     to: raw[i + 1])
                let d2 = direction(from: raw[i + 1], to: raw[i + 2])
                dotAfter = dot(d1, d2)
            }

            let isSharp = min(abs(dotBefore), abs(dotAfter)) < 0.5
            let segDist  = sphericalDist(raw[i], raw[i + 1])
            let spacing  = isSharp ? 3.5 : 150.0
            let nSub     = max(1, Int(ceil(segDist / spacing)))

            refined.append(raw[i])
            for j in 1..<nSub {
                let t = Double(j) / Double(nSub)
                refined.append(lerp(raw[i], raw[i + 1], t: t))
            }
        }
        refined.append(raw.last!)

        // Midpoint smoothing pass
        var smoothed: [GeoPoint] = [refined.first!]
        for i in 0..<(refined.count - 1) {
            smoothed.append(lerp(refined[i], refined[i + 1], t: 0.5))
        }
        smoothed.append(refined.last!)
        return smoothed
    }

    private static func lerp(_ a: GeoPoint, _ b: GeoPoint, t: Double) -> GeoPoint {
        GeoPoint(latitude:  a.latitude  * (1 - t) + b.latitude  * t,
                 longitude: a.longitude * (1 - t) + b.longitude * t)
    }

    // MARK: - Step 3 & 4: Spline fit + sampling

    private static func sampleRoutePoints(spline: Spline) -> [SplineRoutePoint] {
        let totalLen = spline.timeSteps.last!
        guard totalLen > 0 else { return [] }

        let curveTypes = RallyCurveType.defaults.sorted { $0.rank < $1.rank }
        var pts: [SplineRoutePoint] = []
        var t = 0.0

        while t <= totalLen {
            let i = spline.findInterval(t: t)
            let lat = spline.latitude.sample(i: i, t: t)
            let lon = spline.longitude.sample(i: i, t: t)
            let coord = GeoPoint(
                latitude:  lat * 180 / .pi,
                longitude: lon * 180 / .pi
            )
            let kappa = spline.curvature(i: i, t: t)

            var rank = -1
            for ct in curveTypes {
                if abs(kappa) > ct.curvatureThreshold { rank = ct.rank }
            }
            let orientation = kappa > 0

            pts.append(SplineRoutePoint(
                progress:    t,
                coords:      coord,
                curvature:   kappa,
                rank:        rank,
                orientation: orientation
            ))
            t += NavConstants.delta
        }
        return pts
    }

    // MARK: - Step 6: Build initial curves

    private static func buildCurves(routePoints: [SplineRoutePoint]) -> [RallyCurve] {
        let curveTypes = RallyCurveType.defaults.sorted { $0.rank > $1.rank } // highest first
        var curves: [RallyCurve] = []

        for ct in curveTypes {
            var startIdx = -1

            func closeCurve(endIdx: Int) {
                guard startIdx >= 0 else { return }
                curves.append(RallyCurve(
                    typeName:    ct.name,
                    rank:        ct.rank,
                    startIndex:  startIdx,
                    endIndex:    endIdx,
                    start:       routePoints[startIdx].progress,
                    end:         routePoints[endIdx].progress,
                    orientation: routePoints[startIdx].orientation
                ))
                startIdx = -1
            }

            for i in 0..<routePoints.count {
                let pt = routePoints[i]
                if pt.rank == ct.rank {
                    if startIdx >= 0 && routePoints[startIdx].orientation != pt.orientation {
                        closeCurve(endIdx: i)
                        startIdx = i
                    } else if startIdx < 0 {
                        startIdx = i
                    }
                } else if startIdx >= 0 {
                    closeCurve(endIdx: i)
                }
            }
            if startIdx >= 0 {
                closeCurve(endIdx: routePoints.count - 1)
            }
        }

        return curves.sorted { $0.start < $1.start }
    }

    // MARK: - Step 7: Local maxima filter

    private static func findLocalMaximaCurves(_ curves: [RallyCurve]) -> [RallyCurve] {
        guard curves.count > 2 else { return curves }
        var result: [RallyCurve] = []

        for i in 0..<curves.count {
            let cur  = curves[i].rank
            let prev = i > 0                    ? curves[i - 1].rank : 0
            let next = i < curves.count - 1     ? curves[i + 1].rank : 0
            if cur >= prev && cur >= next {
                result.append(curves[i])
            }
        }
        return result.isEmpty ? curves : result
    }

    // MARK: - Step 8a: Remove overlap

    private static func removeOverlap(_ curves: [RallyCurve]) -> [RallyCurve] {
        guard curves.count >= 2 else { return curves }
        var result: [RallyCurve] = []
        var prev = curves[0]

        for i in 1..<curves.count {
            var cur = curves[i]
            if cur.start < prev.end {
                let midProg = (prev.end + cur.start) / 2
                prev = RallyCurve(typeName: prev.typeName, rank: prev.rank,
                                  startIndex: prev.startIndex, endIndex: prev.endIndex,
                                  start: prev.start, end: midProg,
                                  orientation: prev.orientation)
                cur  = RallyCurve(typeName: cur.typeName, rank: cur.rank,
                                  startIndex: cur.startIndex, endIndex: cur.endIndex,
                                  start: midProg, end: cur.end,
                                  orientation: cur.orientation)
            }
            result.append(prev)
            prev = cur
        }
        result.append(prev)
        return result
    }

    // MARK: - Step 8b: Join curves

    private static func joinCurves(_ curves: [RallyCurve]) -> [RallyCurve] {
        guard curves.count >= 2 else { return curves }
        var result: [RallyCurve] = []
        var i = 0

        while i < curves.count {
            var cur = curves[i]
            var j = i + 1
            while j < curves.count {
                let nxt = curves[j]
                guard cur.orientation == nxt.orientation else { break }
                let gap = nxt.start - cur.end
                if gap > NavConstants.maxDistJoin { break }
                cur = RallyCurve(
                    typeName:    cur.typeName,
                    rank:        min(cur.rank, nxt.rank),
                    startIndex:  cur.startIndex,
                    endIndex:    nxt.endIndex,
                    start:       cur.start,
                    end:         nxt.end,
                    orientation: cur.orientation
                )
                j += 1
            }
            result.append(cur)
            i = j
        }
        return result
    }

    // MARK: - Step 8c: Stick broken curves

    private static func stickBrokenCurves(_ curves: [RallyCurve]) -> [RallyCurve] {
        guard curves.count >= 2 else { return curves }
        var output: [RallyCurve] = []
        var i = 0

        while i < curves.count {
            var end = i
            while end + 1 < curves.count {
                let a = curves[end], b = curves[end + 1]
                if a.orientation != b.orientation { break }
                let rankDiff = abs(a.rank - b.rank)
                let gapDist  = b.start - a.end
                if rankDiff > 2 || gapDist > NavConstants.maxDistStick { break }
                end += 1
            }

            if end > i {
                let merged = RallyCurve(
                    typeName:    curves[i].typeName,
                    rank:        min(curves[i].rank, curves[end].rank),
                    startIndex:  curves[i].startIndex,
                    endIndex:    curves[end].endIndex,
                    start:       curves[i].start,
                    end:         curves[end].end,
                    orientation: curves[i].orientation
                )
                output.append(merged)
                i = end + 1
            } else {
                output.append(curves[i])
                i += 1
            }
        }
        return output
    }

    // MARK: - Minimum length filter

    /// Removes curves that are too short to be meaningful after all merging passes.
    private static func removeShortCurves(_ curves: [RallyCurve]) -> [RallyCurve] {
        curves.filter { $0.length >= NavConstants.minCurveLength }
    }

    // MARK: - Step 9: Hairpin / square reclassification

    private static func findHairpins(curves: [RallyCurve],
                                     routePoints: [SplineRoutePoint]) -> [RallyCurve] {
        return curves.map { curve in
            guard curve.rank >= 7 else { return curve }  // only square(7) / hairpin(8)
            let angle = traversedAngle(routePoints: routePoints,
                                       startIndex: curve.startIndex,
                                       endIndex:   curve.endIndex)
            var updated = curve
            if angle >= NavConstants.hairpinAngleThreshold {
                updated = RallyCurve(typeName: "hairpin", rank: 8,
                                     startIndex: curve.startIndex, endIndex: curve.endIndex,
                                     start: curve.start, end: curve.end,
                                     orientation: curve.orientation)
            } else if angle < NavConstants.squareLower || angle >= NavConstants.squareUpper
                          || curve.length >= NavConstants.squareMaxLength {
                // Downgrade to highest enabled regular type
                let downgrade = RallyCurveType.defaults
                    .filter { $0.name != "square" && $0.name != "hairpin" }
                    .max { $0.rank < $1.rank }!
                updated = RallyCurve(typeName: downgrade.name, rank: downgrade.rank,
                                     startIndex: curve.startIndex, endIndex: curve.endIndex,
                                     start: curve.start, end: curve.end,
                                     orientation: curve.orientation)
            }
            return updated
        }
    }

    // MARK: - Step 10: Modifiers

    private static func applyModifiers(_ curve: RallyCurve) -> RallyCurve {
        guard curve.rank >= 1 && curve.rank <= 6 else { return curve } // no modifiers for square/hairpin
        guard let ct = RallyCurveType.defaults.first(where: { $0.rank == curve.rank }) else { return curve }

        var c = curve
        c.isShort     = curve.length < ct.shortLength
        c.isLong      = curve.length > ct.longLength
        c.isExtraLong = curve.length > ct.longLength * 1.6
        return c
    }

    // MARK: - Geometry helpers

    /// Total angle traversed (degrees) from start to end of a curve.
    static func traversedAngle(routePoints pts: [SplineRoutePoint],
                               startIndex: Int, endIndex: Int) -> Double {
        let n = pts.count
        let s = max(0, startIndex)
        let e = min(n - 1, endIndex)
        guard s < e else { return 0 }
        let bIn  = bearing(from: pts[max(0, s - 1)].coords.clCoordinate,
                           to:   pts[s].coords.clCoordinate)
        let bOut = bearing(from: pts[e].coords.clCoordinate,
                           to:   pts[min(n - 1, e + 1)].coords.clCoordinate)
        return abs(normaliseDelta(bOut - bIn))
    }

    static func bearing(from a: CLLocationCoordinate2D,
                        to b: CLLocationCoordinate2D) -> Double {
        let φ1 = a.latitude  * .pi / 180
        let φ2 = b.latitude  * .pi / 180
        let Δλ = (b.longitude - a.longitude) * .pi / 180
        let y  = sin(Δλ) * cos(φ2)
        let x  = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        var deg = atan2(y, x) * 180 / .pi
        if deg < 0 { deg += 360 }
        return deg
    }

    static func normaliseDelta(_ deg: Double) -> Double {
        var a = deg.truncatingRemainder(dividingBy: 360)
        if a >  180 { a -= 360 }
        if a < -180 { a += 360 }
        return a
    }

    // Flat-Earth approximation direction unit vector
    private static func direction(from a: GeoPoint, to b: GeoPoint) -> (Double, Double) {
        let dx = (b.longitude - a.longitude) * cos(a.latitude * .pi / 180)
        let dy =  b.latitude  - a.latitude
        let len = sqrt(dx * dx + dy * dy)
        guard len > 1e-12 else { return (0, 0) }
        return (dx / len, dy / len)
    }

    private static func dot(_ a: (Double, Double), _ b: (Double, Double)) -> Double {
        a.0 * b.0 + a.1 * b.1
    }

    private static func sphericalDist(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let loc1 = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let loc2 = CLLocation(latitude: b.latitude, longitude: b.longitude)
        return loc1.distance(from: loc2)
    }
}

// MARK: - Spline1D

final class Spline1D {
    let timeSteps: [Double]
    let a: [Double]
    let b: [Double]
    let c: [Double]
    let d: [Double]

    init(timeSteps: [Double], a: [Double], b: [Double], c: [Double], d: [Double]) {
        self.timeSteps = timeSteps
        self.a = a; self.b = b; self.c = c; self.d = d
    }

    func sample(i: Int, t: Double) -> Double {
        let dt = t - timeSteps[i]
        return a[i] + b[i] * dt + c[i] * dt * dt + d[i] * dt * dt * dt
    }

    func first(i: Int, t: Double) -> Double {
        let dt = t - timeSteps[i]
        return b[i] + 2 * c[i] * dt + 3 * d[i] * dt * dt
    }

    func sec(i: Int, t: Double) -> Double {
        let dt = t - timeSteps[i]
        return 2 * c[i] + 6 * d[i] * dt
    }
}

// MARK: - Spline (2-D)

final class Spline {
    let latitude:  Spline1D
    let longitude: Spline1D
    let timeSteps: [Double]

    /// Returns nil if fewer than 2 distinct points after deduplication.
    init?(points: [GeoPoint]) {
        var lats:  [Double] = []
        var lons:  [Double] = []
        var times: [Double] = [0]

        lats.append(points[0].latitude  * .pi / 180)
        lons.append(points[0].longitude * .pi / 180)

        for i in 1..<points.count {
            let loc1 = CLLocation(latitude: points[i - 1].latitude, longitude: points[i - 1].longitude)
            let loc2 = CLLocation(latitude: points[i].latitude,     longitude: points[i].longitude)
            let dist = loc1.distance(from: loc2)
            if dist > 0 {
                times.append(times.last! + dist)
                lats.append(points[i].latitude  * .pi / 180)
                lons.append(points[i].longitude * .pi / 180)
            }
        }

        guard times.count >= 4 else { return nil }

        let latCoeffs = Spline.splineAlgorithm(x: times, y: lats)
        let lonCoeffs = Spline.splineAlgorithm(x: times, y: lons)

        self.timeSteps = times
        self.latitude  = Spline1D(timeSteps: times, a: latCoeffs[0], b: latCoeffs[1],
                                  c: latCoeffs[2], d: latCoeffs[3])
        self.longitude = Spline1D(timeSteps: times, a: lonCoeffs[0], b: lonCoeffs[1],
                                  c: lonCoeffs[2], d: lonCoeffs[3])
    }

    // MARK: Natural cubic spline (Thomas algorithm)

    static func splineAlgorithm(x: [Double], y: [Double]) -> [[Double]] {
        let n  = x.count
        let n1 = n - 1

        let a = y
        var b = [Double](repeating: 0, count: n1)
        var c = [Double](repeating: 0, count: n)
        var d = [Double](repeating: 0, count: n1)

        var h = [Double]()
        for i in 0..<n1 { h.append(x[i + 1] - x[i]) }

        var alpha = [Double]()
        for i in 1..<n1 {
            alpha.append((3.0 / h[i]) * (a[i + 1] - a[i])
                       - (3.0 / h[i - 1]) * (a[i] - a[i - 1]))
        }

        var l  = [Double](repeating: 0, count: n)
        var mu = [Double](repeating: 0, count: n)
        var z  = [Double](repeating: 0, count: n)

        l[0] = 1; mu[0] = 0; z[0] = 0

        for i in 1..<n1 {
            l[i]  = 2.0 * (x[i + 1] - x[i - 1]) - h[i - 1] * mu[i - 1]
            mu[i] = h[i] / l[i]
            z[i]  = (alpha[i - 1] - h[i - 1] * z[i - 1]) / l[i]
        }

        l[n1] = 1; z[n1] = 0; c[n1] = 0

        for j in stride(from: n - 2, through: 0, by: -1) {
            c[j] = z[j] - mu[j] * c[j + 1]
            b[j] = (a[j + 1] - a[j]) / h[j] - h[j] * (c[j + 1] + 2.0 * c[j]) / 3.0
            d[j] = (c[j + 1] - c[j]) / (3.0 * h[j])
        }

        let aSlice = Array(a[0..<n1])
        let cSlice = Array(c[0..<n1])
        return [aSlice, b, cSlice, d]
    }

    // MARK: Interval search (binary search)

    func findInterval(t: Double) -> Int {
        let n = timeSteps.count
        guard t >= timeSteps[0] else { return 0 }
        guard t <  timeSteps[n - 1] else { return n - 2 }

        var lo = 0, hi = n - 2
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if timeSteps[mid] <= t { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }

    // MARK: Signed 3-D curvature on a sphere (section 4.1 of the document)

    func curvature(i: Int, t: Double) -> Double {
        let latVal  = latitude.sample(i: i, t: t)
        let lonVal  = longitude.sample(i: i, t: t)
        let latFst  = latitude.first(i: i, t: t)
        let lonFst  = longitude.first(i: i, t: t)
        let latSec  = latitude.sec(i: i, t: t)
        let lonSec  = longitude.sec(i: i, t: t)

        let sinLat = sin(latVal), cosLat = cos(latVal)
        let sinLon = sin(lonVal), cosLon = cos(lonVal)
        let R = NavConstants.earthRadius

        // Sign of curvature
        let sign: Double = (latFst * lonSec - lonFst * latSec) >= 0 ? 1.0 : -1.0

        // Velocity (first derivative of Cartesian position)
        let vx = (-R * sinLon * cosLat) * lonFst - (R * cosLon * sinLat) * latFst
        let vy =  (R * cosLon * cosLat) * lonFst - (R * sinLon * sinLat) * latFst
        let vz =   R * cosLat * latFst

        // Acceleration (second derivative)
        let ax = -R * (((cosLon * cosLat * lonFst) - (sinLon * sinLat * latFst)) * lonFst
                     + (sinLon * cosLat) * lonSec
                     + ((-sinLon * sinLat * lonFst) + (cosLon * cosLat * latFst)) * latFst
                     + (cosLon * sinLat) * latSec)

        let ay =  R * ((((-sinLon * cosLat * lonFst) - (cosLon * sinLat * latFst)) * lonFst
                     + (cosLon * cosLat) * lonSec)
                     - ((cosLon * sinLat * lonFst) + (sinLon * cosLat * latFst)) * latFst
                     - (sinLon * sinLat) * latSec)

        let az =  R * (cosLat * latSec - sinLat * latFst * latFst)

        // |v × a|
        let crossMag = sqrt(
            pow(vy * az - ay * vz, 2) +
            pow(ax * vz - az * vx, 2) +
            pow(ay * vx - ax * vy, 2)
        )

        let speed = sqrt(vx * vx + vy * vy + vz * vz)
        guard speed > 1e-12 else { return 0 }
        let speedCubed = speed * speed * speed

        let kappa3D = crossMag / speedCubed
        let earthCurvature = 1.0 / R

        let kappaSquared = kappa3D * kappa3D - earthCurvature * earthCurvature
        guard kappaSquared > 0 else { return 0 }
        return sign * sqrt(kappaSquared)
    }
}
