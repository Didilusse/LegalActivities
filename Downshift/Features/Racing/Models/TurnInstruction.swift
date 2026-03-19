//
//  TurnInstruction.swift
//  Downshift
//
//  Converts a route polyline into rally pace-note instructions.
//
//  Pipeline (based on Rally.md reverse-engineering notes):
//    1.  Adaptive polyline refinement  — 3.5 m spacing near curves, 150 m on straights
//    2.  Midpoint smoothing            — pairwise midpoints pass
//    3.  RoutePoint generation         — constant-delta samples with cumulative distance & heading
//    4.  Raw curve detection           — accumulate heading delta > ANGLE_THRESHOLD, tag orientation
//    5.  Local-maxima filter           — keep only extrema of curvature magnitude
//    6.  Overlap removal               — split overlapping curve pairs at midpoint
//    7.  Join curves                   — merge adjacent same-direction curves with small gap
//    8.  Stick broken curves (×2)      — fuse nearly-contiguous fragments
//    9.  Hairpin / square override     — reclassify by actual traversed angle
//   10.  Modifiers                     — flag short / long / extra-long
//   11.  Emit TurnInstruction list
//
//  Rally severity scale (WRC / Dirt Rally convention):
//    1 = hairpin  (≥ 150°)
//    2 = square   (75–150°, or 75–115° + short for true square)
//    3 = six      → maps to severity 3 below
//    4 = five
//    5 = four
//    6 = nearly flat bend
//  FLAT / STRAIGHT = pure straight, shown as "Flat" in rally mode.
//  FINISH is its own special case.
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - TurnDirection (standard mode labels)

enum TurnDirection: String {
    case straight     = "Straight"
    case slightLeft   = "Slight Left"
    case left         = "Left"
    case sharpLeft    = "Sharp Left"
    case hairpinLeft  = "Hairpin Left"
    case slightRight  = "Slight Right"
    case right        = "Right"
    case sharpRight   = "Sharp Right"
    case hairpinRight = "Hairpin Right"
    case finish       = "Finish"

    var systemImage: String {
        switch self {
        case .straight:     return "arrow.up"
        case .slightLeft:   return "arrow.up.left"
        case .left:         return "arrow.turn.up.left"
        case .sharpLeft:    return "arrow.left"
        case .hairpinLeft:  return "arrow.uturn.left"
        case .slightRight:  return "arrow.up.right"
        case .right:        return "arrow.turn.up.right"
        case .sharpRight:   return "arrow.right"
        case .hairpinRight: return "arrow.uturn.right"
        case .finish:       return "flag.checkered"
        }
    }
}

// MARK: - TurnInstruction

struct TurnInstruction: Identifiable {
    let id = UUID()

    /// Standard nav direction label.
    let direction: TurnDirection

    /// Distance in metres from the *previous* instruction's waypoint to this one.
    let distanceToTurn: Double

    /// The coordinate at which this instruction applies (the waypoint itself).
    let waypointCoordinate: CLLocationCoordinate2D

    /// Index in the route coordinate array.
    let waypointIndex: Int

    // MARK: Rally-specific fields

    /// 1 (tightest hairpin) … 6 (nearly flat bend). nil for straight or finish.
    let rallySeverity: Int?

    /// true = left, false = right, nil = straight/finish.
    let rallyIsLeft: Bool?

    /// Optional modifier text ("Short" / "Long" / "Extra Long")
    let rallyModifier: String?

    // MARK: - Standard display

    func standardText(units: UnitPreference) -> String {
        switch direction {
        case .finish:   return "Finish Line"
        case .straight: return "Continue · \(fmt(distanceToTurn, units: units))"
        default:        return "\(direction.rawValue) in \(fmt(distanceToTurn, units: units))"
        }
    }

    func shortText(units: UnitPreference) -> String {
        switch direction {
        case .finish:   return "Finish"
        case .straight: return "Straight · \(fmt(distanceToTurn, units: units))"
        default:        return "\(direction.rawValue) · \(fmt(distanceToTurn, units: units))"
        }
    }

    // MARK: - Rally display

    /// Human-readable pace-note string, e.g. "3 Right Long" or "Flat" or "FINISH".
    var rallyNoteText: String {
        if direction == .finish { return "FINISH" }
        guard let sev = rallySeverity, let isLeft = rallyIsLeft else { return "Flat" }
        let modStr = rallyModifier.map { " \($0)" } ?? ""
        return "\(sev) \(isLeft ? "Left" : "Right")\(modStr)"
    }

    /// The distance to call before this note, e.g. "350 m" or "1.2 km".
    func rallyDistanceText(units: UnitPreference) -> String {
        fmt(distanceToTurn, units: units)
    }

    // MARK: - Formatting helper

    private func fmt(_ meters: Double, units: UnitPreference) -> String {
        if units == .metric {
            return meters >= 1000
                ? String(format: "%.1f km", meters / 1000)
                : "\(Int(meters.rounded())) m"
        } else {
            let feet = meters * 3.28084
            return feet >= 5280
                ? String(format: "%.1f mi", feet / 5280)
                : "\(Int(feet.rounded())) ft"
        }
    }

    // MARK: - Factory

    /// Builds pace-note instructions from a coordinate list using the cubic-spline
    /// curvature pipeline from RALLY_NAVIGATION_TECHNICAL_DOCUMENT.md.
    /// Falls back to the heading-delta pipeline when the spline engine returns nothing.
    static func buildInstructions(for coords: [CLLocationCoordinate2D],
                                  units: UnitPreference) -> [TurnInstruction] {
        guard coords.count >= 2 else { return [] }

        // ── Spline-based pipeline (primary) ──────────────────────────────────────
        let splineCurves = RallyNavigationEngine.detectCurves(from: coords)
        if !splineCurves.isEmpty {
            return emitSplineInstructions(curves: splineCurves,
                                          originalCoords: coords,
                                          units: units)
        }

        // ── Heading-delta fallback (for very short routes / edge cases) ───────────
        let refined = refinePolyline(raw: coords)
        guard refined.count >= 3 else {
            return [
                TurnInstruction(direction: .straight, distanceToTurn: 0,
                                waypointCoordinate: coords[0], waypointIndex: 0,
                                rallySeverity: nil, rallyIsLeft: nil, rallyModifier: nil),
                TurnInstruction(direction: .finish,
                                distanceToTurn: segmentDist(coords[0], coords[coords.count - 1]),
                                waypointCoordinate: coords[coords.count - 1],
                                waypointIndex: coords.count - 1,
                                rallySeverity: nil, rallyIsLeft: nil, rallyModifier: nil)
            ]
        }

        let routePoints = buildRoutePoints(refined, delta: 5.0)
        guard routePoints.count >= 3 else {
            return fallbackInstructions(coords: coords)
        }

        var curves = buildCurves(routePoints: routePoints)
        curves = findLocalMaximaCurves(curves)
        curves = removeOverlap(curves)
        curves = joinCurves(curves)
        curves = stickBrokenCurves(curves)
        curves = stickBrokenCurves(curves)
        curves = findHairpins(curves: curves, routePoints: routePoints)
        curves = curves.map { applyModifiers($0) }
        return emitInstructions(curves: curves, routePoints: routePoints,
                                originalCoords: coords, units: units)
    }

    // MARK: - Spline-curve instruction emission

    /// Converts the output of RallyNavigationEngine into TurnInstruction values.
    private static func emitSplineInstructions(curves: [RallyCurve],
                                               originalCoords: [CLLocationCoordinate2D],
                                               units: UnitPreference) -> [TurnInstruction] {
        var result: [TurnInstruction] = []

        // Opening straight
        result.append(TurnInstruction(
            direction: .straight, distanceToTurn: 0,
            waypointCoordinate: originalCoords[0], waypointIndex: 0,
            rallySeverity: nil, rallyIsLeft: nil, rallyModifier: nil
        ))

        // Total route distance (straight-line sum of original coords)
        var totalDist = 0.0
        for i in 1..<originalCoords.count {
            totalDist += segmentDist(originalCoords[i - 1], originalCoords[i])
        }

        var lastEmitDist: Double = 0

        for curve in curves {
            let distSince = curve.start - lastEmitDist
            lastEmitDist  = curve.start

            // Map rank to TurnDirection
            let dir = splineRankToDirection(rank: curve.rank, isLeft: !curve.orientation)

            // Modifier text
            let mod: String?
            if curve.isExtraLong { mod = "Extra Long" }
            else if curve.isLong  { mod = "Long" }
            else if curve.isShort { mod = "Short" }
            else                  { mod = nil }

            // Find the closest coordinate in the original array to the curve start
            let waypointCoord = closestCoord(in: originalCoords, toProgress: curve.start, totalDist: totalDist)
            let waypointIdx   = closestIndex(in: originalCoords, toProgress: curve.start, totalDist: totalDist)

            // Rally severity: map rank 1–8 back to display scale 1–6
            // rank 8=hairpin→1, 7=square→2, 6=one→3, 5=two→4, 4=three→4, 3=four→5, 2=five→5, 1=six→6
            let rallySev = splineRankToSeverity(rank: curve.rank)

            result.append(TurnInstruction(
                direction:          dir,
                distanceToTurn:     max(0, distSince),
                waypointCoordinate: waypointCoord,
                waypointIndex:      waypointIdx,
                rallySeverity:      rallySev,
                rallyIsLeft:        !curve.orientation,
                rallyModifier:      mod
            ))
        }

        // Finish
        let distToFinish = totalDist - lastEmitDist
        result.append(TurnInstruction(
            direction: .finish,
            distanceToTurn: max(0, distToFinish),
            waypointCoordinate: originalCoords[originalCoords.count - 1],
            waypointIndex: originalCoords.count - 1,
            rallySeverity: nil, rallyIsLeft: nil, rallyModifier: nil
        ))

        return result
    }

    /// Maps spline rank (1–8) to TurnDirection.
    private static func splineRankToDirection(rank: Int, isLeft: Bool) -> TurnDirection {
        if isLeft {
            switch rank {
            case 8:         return .hairpinLeft
            case 7:         return .sharpLeft
            case 5, 6:      return .left
            default:        return .slightLeft
            }
        } else {
            switch rank {
            case 8:         return .hairpinRight
            case 7:         return .sharpRight
            case 5, 6:      return .right
            default:        return .slightRight
            }
        }
    }

    /// Maps spline rank (1–8) to the display severity (1–6).
    private static func splineRankToSeverity(rank: Int) -> Int {
        switch rank {
        case 8: return 1  // hairpin → tightest
        case 7: return 2  // square
        case 6: return 3  // one
        case 5: return 4  // two
        case 4: return 4  // three
        case 3: return 5  // four
        case 2: return 5  // five
        default: return 6 // six → gentlest
        }
    }

    /// Returns the coordinate in `coords` whose fractional progress along the route best
    /// matches `targetProgress` / `totalDist`.
    private static func closestCoord(in coords: [CLLocationCoordinate2D],
                                     toProgress targetProgress: Double,
                                     totalDist: Double) -> CLLocationCoordinate2D {
        guard !coords.isEmpty else { return CLLocationCoordinate2D() }
        guard totalDist > 0 else { return coords[0] }
        var cum = 0.0
        for i in 1..<coords.count {
            let segLen = segmentDist(coords[i - 1], coords[i])
            if cum + segLen >= targetProgress {
                return coords[i - 1]
            }
            cum += segLen
        }
        return coords[coords.count - 1]
    }

    private static func closestIndex(in coords: [CLLocationCoordinate2D],
                                     toProgress targetProgress: Double,
                                     totalDist: Double) -> Int {
        guard !coords.isEmpty else { return 0 }
        guard totalDist > 0 else { return 0 }
        var cum = 0.0
        for i in 1..<coords.count {
            let segLen = segmentDist(coords[i - 1], coords[i])
            if cum + segLen >= targetProgress {
                return i - 1
            }
            cum += segLen
        }
        return coords.count - 1
    }

    // MARK: - Step 1: Polyline Refinement

    /// Densifies the polyline at uniform 5 m spacing, then applies a midpoint-smoothing pass.
    ///
    /// The adaptive (3.5 m / 150 m) scheme from Rally.md is designed for raw GPS traces where the
    /// underlying road geometry is unknown. Here the input is either road-snapped geometry from
    /// MKDirections (already detailed) or user-placed waypoints — both cases are best served by a
    /// uniform tight resample that preserves every road curve without the large 150 m gaps that
    /// straight-line interpolation would introduce across straights.
    private static func refinePolyline(raw: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        // Uniform 5 m resample preserves all road geometry
        let resampled = resampleUniform(raw, stepMetres: 5.0)

        // Midpoint smoothing: first point → midpoints between each pair → last point
        guard resampled.count >= 2 else { return resampled }
        var smoothed: [CLLocationCoordinate2D] = [resampled[0]]
        for i in 0..<(resampled.count - 1) {
            smoothed.append(interpolate(resampled[i], resampled[i + 1], t: 0.5))
        }
        smoothed.append(resampled[resampled.count - 1])
        return smoothed
    }

    // MARK: - Step 2: RoutePoint generation

    struct RoutePoint {
        let coord: CLLocationCoordinate2D
        let cumulativeDist: Double  // metres from start
        let heading: Double         // degrees, 0–360, true north
    }

    /// Wraps the already-refined (uniformly spaced) coords into RoutePoints with cumulative distance.
    /// The heading field stores the bearing to the *next* point; buildCurves recomputes per-point
    /// bearings from coordinates directly, so the stored heading is only used for distance tracking.
    private static func buildRoutePoints(_ refined: [CLLocationCoordinate2D],
                                         delta: Double) -> [RoutePoint] {
        guard refined.count >= 2 else { return [] }
        var result: [RoutePoint] = []
        var cumDist = 0.0

        for i in 0..<refined.count {
            let h: Double
            if i + 1 < refined.count {
                h = bearing(from: refined[i], to: refined[i + 1])
            } else {
                h = result.last?.heading ?? 0
            }
            result.append(RoutePoint(coord: refined[i], cumulativeDist: cumDist, heading: h))
            if i + 1 < refined.count {
                cumDist += segmentDist(refined[i], refined[i + 1])
            }
        }
        return result
    }

    // MARK: - Curve model

    struct CurveData {
        var startIndex: Int
        var endIndex: Int
        var startDist: Double
        var endDist: Double
        /// true = left, false = right
        var isLeft: Bool
        /// Raw curvature magnitude (accumulated heading change, degrees)
        var curvature: Double
        /// Rally severity rank 1–6 (1 = hairpin/tightest)
        var rank: Int

        var length: Double { endDist - startDist }
    }

    // MARK: - Step 3: Build raw curves

    private static let angleThreshold: Double = 9.0    // °, minimum per-point heading change
    private static let minTurnDeg: Double     = 15.0   // minimum net angle to emit a note

    /// Detect curves by accumulating the net bearing change across a sliding window of route points.
    ///
    /// This approach works for both:
    ///  - Smooth road curves (many small per-point deltas that add up)
    ///  - Piecewise-linear geometry (one large spike at a segment junction)
    ///
    /// A box-filter smoother kills the piecewise case (spreads a 45° spike over 9 points → 5°
    /// which falls below threshold), so we accumulate raw per-point deltas directly and use a
    /// "straight run" counter to decide when a turn has ended.
    private static func buildCurves(routePoints: [RoutePoint]) -> [CurveData] {
        guard routePoints.count >= 3 else { return [] }

        // Per-point heading deltas using actual coordinate bearings (not stored segment headings).
        var rawDelta = [Double](repeating: 0, count: routePoints.count)
        for i in 1..<(routePoints.count - 1) {
            let bIn  = bearing(from: routePoints[i - 1].coord, to: routePoints[i].coord)
            let bOut = bearing(from: routePoints[i].coord,     to: routePoints[i + 1].coord)
            rawDelta[i] = normaliseDelta(bOut - bIn)
        }

        // Lightly smooth with ±1 window only — removes single-point GPS noise without killing
        // the angular signal at segment junctions (a ±4 window reduces a 45° spike to ~5°).
        let halfW = 1
        var smoothDelta = [Double](repeating: 0, count: routePoints.count)
        for i in 0..<routePoints.count {
            let lo = max(0, i - halfW)
            let hi = min(routePoints.count - 1, i + halfW)
            var sum = 0.0
            for j in lo...hi { sum += rawDelta[j] }
            smoothDelta[i] = sum / Double(hi - lo + 1)
        }

        var curves: [CurveData] = []
        var i = 1
        var inCurve = false
        var turnStart = 0
        var accAngle = 0.0
        // After a turn ends, need this many consecutive low-delta points before starting another.
        // 4 points × 5 m ≈ 20 m of straight.
        let endRunNeeded = 4
        var cooldown = 0

        while i < routePoints.count - 1 {
            if cooldown > 0 { cooldown -= 1; i += 1; continue }
            let angle = smoothDelta[i]

            if inCurve {
                // Count consecutive near-zero points to detect end of turn
                var runLen = 0
                var j = i
                while j < routePoints.count && abs(smoothDelta[j]) <= angleThreshold { runLen += 1; j += 1 }

                if runLen >= endRunNeeded {
                    // Turn has ended — emit it
                    let true_ = trueAngle(pts: routePoints, start: turnStart, end: i - 1, w: 2)
                    if abs(true_) >= minTurnDeg {
                        let left = true_ > 0
                        curves.append(CurveData(
                            startIndex: turnStart, endIndex: i - 1,
                            startDist: routePoints[turnStart].cumulativeDist,
                            endDist:   routePoints[i - 1].cumulativeDist,
                            isLeft: left, curvature: abs(true_), rank: angleToRank(abs(true_))
                        ))
                    }
                    inCurve = false; accAngle = 0; cooldown = endRunNeeded; i = j
                    continue
                }

                // Direction reversal (chicane): split if reversal is sustained
                if accAngle * angle < 0 && abs(angle) > angleThreshold {
                    var revRun = 0
                    for k in i..<min(i + endRunNeeded, routePoints.count) {
                        if smoothDelta[k] * accAngle < 0 { revRun += 1 } else { break }
                    }
                    if revRun >= endRunNeeded {
                        let true_ = trueAngle(pts: routePoints, start: turnStart, end: i - 1, w: 2)
                        if abs(true_) >= minTurnDeg {
                            let left = true_ > 0
                            curves.append(CurveData(
                                startIndex: turnStart, endIndex: i - 1,
                                startDist: routePoints[turnStart].cumulativeDist,
                                endDist:   routePoints[i - 1].cumulativeDist,
                                isLeft: left, curvature: abs(true_), rank: angleToRank(abs(true_))
                            ))
                        }
                        turnStart = i; accAngle = angle; i += 1; continue
                    }
                }

                accAngle += angle; i += 1
            } else {
                // Enter a turn when the smoothed delta exceeds the threshold.
                // Require two consecutive above-threshold points to avoid single-point noise.
                if abs(angle) > angleThreshold {
                    let next = i + 1 < routePoints.count ? smoothDelta[i + 1] : 0.0
                    if abs(next) > angleThreshold || abs(angle) > 20.0 {
                        // The second condition catches a sharp single-spike junction turn
                        inCurve = true; turnStart = i; accAngle = angle
                    }
                }
                i += 1
            }
        }

        // Flush any open turn at end of route
        if inCurve {
            let true_ = trueAngle(pts: routePoints, start: turnStart, end: routePoints.count - 2, w: 2)
            if abs(true_) >= minTurnDeg {
                let left = true_ > 0
                curves.append(CurveData(
                    startIndex: turnStart, endIndex: routePoints.count - 2,
                    startDist: routePoints[turnStart].cumulativeDist,
                    endDist:   routePoints[routePoints.count - 2].cumulativeDist,
                    isLeft: left, curvature: abs(true_), rank: angleToRank(abs(true_))
                ))
            }
        }
        return curves
    }

    // MARK: - Step 4: Local maxima filter

    /// Keeps only curves that are local extrema of curvature magnitude.
    private static func findLocalMaximaCurves(_ curves: [CurveData]) -> [CurveData] {
        guard curves.count > 2 else { return curves }
        var result: [CurveData] = []
        for i in 0..<curves.count {
            let cur = curves[i].curvature
            let prev = i > 0 ? curves[i - 1].curvature : 0
            let next = i < curves.count - 1 ? curves[i + 1].curvature : 0
            if cur >= prev && cur >= next {
                result.append(curves[i])
            }
        }
        return result.isEmpty ? curves : result
    }

    // MARK: - Step 5: Remove overlap

    /// If two curves overlap in index space, split at midpoint.
    private static func removeOverlap(_ curves: [CurveData]) -> [CurveData] {
        guard curves.count >= 2 else { return curves }
        var result: [CurveData] = []
        var prev = curves[0]
        for i in 1..<curves.count {
            var cur = curves[i]
            if cur.startIndex < prev.endIndex {
                let mid = (prev.endIndex + cur.startIndex) / 2
                prev.endIndex = mid
                cur.startIndex = mid + 1
            }
            result.append(prev)
            prev = cur
        }
        result.append(prev)
        return result
    }

    // MARK: - Step 6: Join curves

    private static let maxDistJoin: Double = 10.0  // metres

    /// Merge adjacent same-direction curves when the gap is small.
    private static func joinCurves(_ curves: [CurveData]) -> [CurveData] {
        guard curves.count >= 2 else { return curves }
        var result: [CurveData] = []
        var i = 0
        while i < curves.count {
            var current = curves[i]
            var j = i + 1
            while j < curves.count {
                let next = curves[j]
                guard current.isLeft == next.isLeft else { break }
                let gap = next.startDist - current.endDist
                let threshold = min(max(current.length, next.length), maxDistJoin)
                if gap > threshold { break }
                // Merge
                current = CurveData(
                    startIndex: current.startIndex, endIndex: next.endIndex,
                    startDist:  current.startDist,  endDist:  next.endDist,
                    isLeft:     current.isLeft,
                    curvature:  max(current.curvature, next.curvature),
                    rank:       min(current.rank, next.rank) // lower rank = tighter
                )
                j += 1
            }
            result.append(current)
            i = j
        }
        return result
    }

    // MARK: - Step 7: Stick broken curves (×2)

    /// Fuses nearly-contiguous fragments that still have close ranks.
    private static func stickBrokenCurves(_ curves: [CurveData]) -> [CurveData] {
        guard curves.count >= 2 else { return curves }
        var output: [CurveData] = []
        var i = 0
        while i < curves.count {
            let start = i
            var end = i
            while end + 1 < curves.count {
                let a = curves[end], b = curves[end + 1]
                if a.isLeft != b.isLeft { break }
                let rankDiff = abs(a.rank - b.rank)
                let gapDist  = b.startDist - a.endDist
                if rankDiff > 1 || gapDist > maxDistJoin * 2 { break }
                end += 1
            }
            if end > start {
                // Weighted split: keep start and end, merge the middle
                let subChain = curves[(start + 1)..<end]
                if subChain.isEmpty {
                    // Just two curves — merge them
                    let merged = CurveData(
                        startIndex: curves[start].startIndex,
                        endIndex:   curves[end].endIndex,
                        startDist:  curves[start].startDist,
                        endDist:    curves[end].endDist,
                        isLeft:     curves[start].isLeft,
                        curvature:  max(curves[start].curvature, curves[end].curvature),
                        rank:       min(curves[start].rank, curves[end].rank)
                    )
                    output.append(merged)
                    i = end + 1
                } else {
                    let avgRank = subChain.map { Double($0.rank) }.reduce(0, +) / Double(subChain.count)
                    let firstRank = Double(curves[start].rank)
                    let lastRank  = Double(curves[end].rank)
                    let w1 = abs(avgRank - firstRank)
                    let w2 = abs(avgRank - lastRank)
                    let totalW = w1 + w2
                    let splitDist: Double
                    if totalW < 1e-9 {
                        splitDist = (curves[start].endDist + curves[end].startDist) / 2
                    } else {
                        splitDist = (w1 * curves[start].endDist + w2 * curves[end].startDist) / totalW
                    }
                    var left = curves[start]
                    left.endDist = splitDist
                    left.endIndex = curves[end].startIndex
                    var right = curves[end]
                    right.startDist = splitDist
                    right.startIndex = curves[end].startIndex
                    output.append(left)
                    output.append(right)
                    i = end + 1
                }
            } else {
                output.append(curves[start])
                i = start + 1
            }
        }
        return output
    }

    // MARK: - Step 8: Hairpin / square reclassification

    private static let hairpinAngleThreshold: Double = 150.0
    private static let squareLower: Double            =  75.0
    private static let squareUpper: Double            = 115.0
    private static let squareMaxLength: Double        =  20.0

    /// Recomputes the traversed angle for each rank-1/2 curve and reclassifies accordingly.
    private static func findHairpins(curves: [CurveData], routePoints: [RoutePoint]) -> [CurveData] {
        return curves.map { curve in
            // Only reclassify potentially square / hairpin candidates (rank 1 or 2)
            guard curve.rank <= 2 else { return curve }
            let angle = traversedAngle(routePoints: routePoints,
                                        startIndex: curve.startIndex,
                                        endIndex:   curve.endIndex)
            var updated = curve
            if angle >= hairpinAngleThreshold {
                updated.rank = 1  // hairpin
            } else if angle >= squareLower && angle < squareUpper && curve.length < squareMaxLength {
                updated.rank = 2  // square
            } else {
                updated.rank = angleToRank(angle)
            }
            updated.curvature = angle
            return updated
        }
    }

    // MARK: - Step 9: Modifiers

    struct CurveModifiers {
        var isShort      = false
        var isLong       = false
        var isExtraLong  = false
    }

    /// Per-rank short/long thresholds (metres). Index = rank-1 (rank 1..6).
    /// Hairpin (1) and square (2) never get length modifiers.
    private static let shortLengths: [Double] = [0, 0, 20, 30, 50, 80]    // rank 1..6
    private static let longLengths:  [Double] = [0, 0, 60, 90, 130, 200]  // rank 1..6

    private static func applyModifiers(_ curve: CurveData) -> CurveData {
        let c = curve
        guard c.rank >= 3 else { return c } // hairpin/square: no modifiers
        let idx = min(c.rank - 1, shortLengths.count - 1)
        let shortLen = shortLengths[idx]
        let longLen  = longLengths[idx]
        // We don't store modifiers back in CurveData — they're used at emit time
        // Store them implicitly through the rank; emit function reads curve.length
        _ = shortLen; _ = longLen
        return c
    }

    /// Returns the modifier string for a curve based on its length and rank.
    private static func modifierText(for curve: CurveData) -> String? {
        guard curve.rank >= 3 else { return nil }
        let idx = min(curve.rank - 1, shortLengths.count - 1)
        let shortLen = shortLengths[idx]
        let longLen  = longLengths[idx]
        if curve.length < shortLen { return "Short" }
        if curve.length > longLen * 1.6 { return "Extra Long" }
        if curve.length > longLen { return "Long" }
        return nil
    }

    // MARK: - Step 10: Emit instructions

    private static func emitInstructions(curves: [CurveData],
                                          routePoints: [RoutePoint],
                                          originalCoords: [CLLocationCoordinate2D],
                                          units: UnitPreference) -> [TurnInstruction] {
        var result: [TurnInstruction] = []
        let totalDist = routePoints.last?.cumulativeDist ?? 0

        // Opening "straight" / start marker
        result.append(TurnInstruction(
            direction: .straight, distanceToTurn: 0,
            waypointCoordinate: originalCoords[0], waypointIndex: 0,
            rallySeverity: nil, rallyIsLeft: nil, rallyModifier: nil
        ))

        var lastEmitDist: Double = 0

        for curve in curves {
            let distSince = curve.startDist - lastEmitDist
            lastEmitDist  = curve.startDist

            let dir = rankToDirection(rank: curve.rank, isLeft: curve.isLeft)
            let mod = modifierText(for: curve)

            // Closest coord in routePoints to curve start
            let rp = routePoints[min(curve.startIndex, routePoints.count - 1)]

            result.append(TurnInstruction(
                direction:          dir,
                distanceToTurn:     max(0, distSince),
                waypointCoordinate: rp.coord,
                waypointIndex:      curve.startIndex,
                rallySeverity:      curve.rank,
                rallyIsLeft:        curve.isLeft,
                rallyModifier:      mod
            ))
        }

        // Finish
        let distToFinish = totalDist - lastEmitDist
        result.append(TurnInstruction(
            direction: .finish,
            distanceToTurn: max(0, distToFinish),
            waypointCoordinate: originalCoords[originalCoords.count - 1],
            waypointIndex: originalCoords.count - 1,
            rallySeverity: nil, rallyIsLeft: nil, rallyModifier: nil
        ))

        return result
    }

    // MARK: - Geometry helpers

    /// True traversed angle across a curve's index range.
    /// Uses vectors at start and end of the curve (approach vs exit).
    private static func traversedAngle(routePoints pts: [RoutePoint],
                                        startIndex: Int, endIndex: Int) -> Double {
        let n = pts.count
        let s = max(0, startIndex)
        let e = min(n - 1, endIndex)
        guard s < e else { return 0 }
        let bIn  = bearing(from: pts[max(0, s - 1)].coord, to: pts[s].coord)
        let bOut = bearing(from: pts[e].coord, to: pts[min(n - 1, e + 1)].coord)
        return abs(normaliseDelta(bOut - bIn))
    }

    /// True turn angle measured by comparing approach/exit bearings.
    /// Positive = left, negative = right.
    private static func trueAngle(pts: [RoutePoint], start: Int, end: Int, w: Int) -> Double {
        let n = pts.count
        let approachStart = max(0, start - w)
        let exitEnd       = min(n - 1, end + w)
        guard approachStart < start, end < exitEnd else {
            if start > 0 && end < n - 1 {
                let bIn  = bearing(from: pts[start - 1].coord, to: pts[start].coord)
                let bOut = bearing(from: pts[end].coord,       to: pts[end + 1].coord)
                return -normaliseDelta(bOut - bIn)
            }
            return 0
        }
        let bIn  = bearing(from: pts[approachStart].coord, to: pts[start].coord)
        let bOut = bearing(from: pts[end].coord,           to: pts[exitEnd].coord)
        return -normaliseDelta(bOut - bIn)
    }

    /// Maps total traversed angle (absolute degrees) → rally rank 1–6.
    private static func angleToRank(_ deg: Double) -> Int {
        switch deg {
        case let a where a >= hairpinAngleThreshold: return 1   // hairpin
        case let a where a >= 85:  return 2   // square / very tight
        case let a where a >= 50:  return 3   // 3 (six in WRC scale)
        case let a where a >= 30:  return 4   // 4 (five)
        case let a where a >= 15:  return 5   // 5 (four)
        default:                   return 6   // 6 (nearly flat)
        }
    }

    private static func rankToDirection(rank: Int, isLeft: Bool) -> TurnDirection {
        if isLeft {
            switch rank {
            case 1:    return .hairpinLeft
            case 2:    return .sharpLeft
            case 3, 4: return .left
            default:   return .slightLeft
            }
        } else {
            switch rank {
            case 1:    return .hairpinRight
            case 2:    return .sharpRight
            case 3, 4: return .right
            default:   return .slightRight
            }
        }
    }

    // MARK: - Fallback

    private static func fallbackInstructions(coords: [CLLocationCoordinate2D]) -> [TurnInstruction] {
        [
            TurnInstruction(direction: .straight, distanceToTurn: 0,
                            waypointCoordinate: coords[0], waypointIndex: 0,
                            rallySeverity: nil, rallyIsLeft: nil, rallyModifier: nil),
            TurnInstruction(direction: .finish,
                            distanceToTurn: segmentDist(coords[0], coords[coords.count - 1]),
                            waypointCoordinate: coords[coords.count - 1],
                            waypointIndex: coords.count - 1,
                            rallySeverity: nil, rallyIsLeft: nil, rallyModifier: nil)
        ]
    }

    // MARK: - Low-level geometry

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

    private static func normaliseDelta(_ deg: Double) -> Double {
        var a = deg.truncatingRemainder(dividingBy: 360)
        if a >  180 { a -= 360 }
        if a < -180 { a += 360 }
        return a
    }

    static func segmentDist(_ a: CLLocationCoordinate2D,
                             _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude,  longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    private static func interpolate(_ a: CLLocationCoordinate2D,
                                    _ b: CLLocationCoordinate2D,
                                    t: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude:  a.latitude  + t * (b.latitude  - a.latitude),
            longitude: a.longitude + t * (b.longitude - a.longitude)
        )
    }

    // Legacy resample kept for any external callers
    static func resampleUniform(_ coords: [CLLocationCoordinate2D],
                                stepMetres: Double) -> [CLLocationCoordinate2D] {
        guard coords.count >= 2 else { return coords }
        var result: [CLLocationCoordinate2D] = [coords[0]]
        var totalArc: Double = 0
        var nextSample: Double = stepMetres
        for i in 1..<coords.count {
            let a = coords[i - 1], b = coords[i]
            let segLen = segmentDist(a, b)
            if segLen < 1e-9 { continue }
            let segStart = totalArc, segEnd = totalArc + segLen
            while nextSample <= segEnd + 1e-9 {
                let t = max(0.0, min(1.0, (nextSample - segStart) / segLen))
                result.append(CLLocationCoordinate2D(
                    latitude:  a.latitude  + t * (b.latitude  - a.latitude),
                    longitude: a.longitude + t * (b.longitude - a.longitude)
                ))
                nextSample += stepMetres
            }
            totalArc = segEnd
        }
        let last = coords[coords.count - 1]
        if let prev = result.last, segmentDist(prev, last) > 1.0 {
            result.append(last)
        }
        return result
    }
}
