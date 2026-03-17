//
//  TurnInstruction.swift
//  LegalActivities
//
//  Computes turn-by-turn and rally pace-note instructions from route waypoints.
//
//  Rally severity scale (WRC / Dirt Rally convention):
//    6 = nearly flat, fast bend          (< 15°)
//    5 = slight bend                     (15–30°)
//    4 = medium corner                   (30–55°)
//    3 = proper corner                   (55–90°)
//    2 = tight corner                    (90–130°)
//    1 = very tight / hairpin            (> 130°)
//  FLAT / STRAIGHT = pure straight (< 5°), shown as "Flat" in rally mode.
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

    /// Distance in metres from the *previous* waypoint to this one.
    let distanceToTurn: Double

    /// The coordinate at which this instruction applies (the waypoint itself).
    let waypointCoordinate: CLLocationCoordinate2D

    /// Index in the route coordinate array.
    let waypointIndex: Int

    // MARK: Rally-specific fields

    /// 1 (tightest hairpin) … 6 (nearly flat bend).
    /// nil for a pure straight or the finish.
    let rallySeverity: Int?

    /// true = left, false = right, nil = straight/finish.
    let rallyIsLeft: Bool?

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

    /// Human-readable pace-note string, e.g. "3 Right" or "Flat" or "FINISH".
    var rallyNoteText: String {
        if direction == .finish { return "FINISH" }
        guard let sev = rallySeverity, let isLeft = rallyIsLeft else { return "Flat" }
        return "\(sev) \(isLeft ? "Left" : "Right")"
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

    /// Builds pace-note instructions from a coordinate list.
    ///
    /// When given dense road-snapped coords (hundreds of points), it smooths micro-jitter
    /// and merges consecutive minor bends into a single note, producing one instruction
    /// per meaningful direction change — just like real rally pace notes.
    ///
    /// When given sparse checkpoint coords (fallback), it behaves as before.
    static func buildInstructions(for coords: [CLLocationCoordinate2D],
                                  units: UnitPreference) -> [TurnInstruction] {
        guard coords.count >= 2 else { return [] }

        // ── 1. Compute smoothed cumulative bearing change at each interior point ──────
        // We look ahead a small window of points to reduce GPS micro-jitter noise.
        let windowSize = min(4, coords.count / 4 + 1)

        struct PointAngle {
            let index: Int
            let coord: CLLocationCoordinate2D
            let angle: Double   // signed, degrees. negative = left, positive = right
            let dist: Double    // metres from previous significant point
        }

        var pointAngles: [PointAngle] = []
        var runningDist: Double = 0

        for i in 1..<(coords.count - 1) {
            // Look back and ahead by windowSize to smooth jitter
            let backIdx  = max(0, i - windowSize)
            let aheadIdx = min(coords.count - 1, i + windowSize)
            let inB  = bearing(from: coords[backIdx], to: coords[i])
            let outB = bearing(from: coords[i], to: coords[aheadIdx])
            let angle = normalise(outB - inB)
            let d = segmentDist(coords[i - 1], coords[i])
            runningDist += d
            pointAngles.append(PointAngle(index: i, coord: coords[i], angle: angle, dist: runningDist))
            runningDist = 0 // reset — we'll accumulate between emitted instructions
        }

        // ── 2. Merge consecutive points into instructions ─────────────────────────────
        // Emit a new instruction only when the cumulative signed angle since the last
        // instruction crosses a significance threshold, OR direction flips.
        // This turns a sweeping curve into a single "3 Left" note rather than dozens.

        let significanceThreshold = 8.0   // degrees — ignore wobbles below this
        let mergeAngleWindow      = 30.0  // degrees — accumulate within this window before emitting

        var result: [TurnInstruction] = []

        // Start instruction
        let startDist = segmentDist(coords[0], coords[1])
        result.append(TurnInstruction(
            direction: .straight,
            distanceToTurn: startDist,
            waypointCoordinate: coords[0],
            waypointIndex: 0,
            rallySeverity: nil,
            rallyIsLeft: nil
        ))

        var accumulatedAngle: Double = 0
        var segDistAccum: Double = startDist
        var lastEmitCoord = coords[0]
        var lastEmitIndex = 0

        for pa in pointAngles {
            segDistAccum += pa.dist

            // Skip tiny wobbles
            if abs(pa.angle) < significanceThreshold { continue }

            // Check if direction flipped (was accumulating left, now strongly right or vice versa)
            let flipped = accumulatedAngle * pa.angle < 0 && abs(accumulatedAngle) > significanceThreshold

            if flipped {
                // Emit the accumulated turn before starting the new one
                if abs(accumulatedAngle) >= significanceThreshold {
                    let instr = makeInstruction(
                        angle: accumulatedAngle,
                        distanceToTurn: segDistAccum - pa.dist,
                        coord: lastEmitCoord,
                        index: lastEmitIndex
                    )
                    result.append(instr)
                }
                accumulatedAngle = pa.angle
                lastEmitCoord = pa.coord
                lastEmitIndex = pa.index
                segDistAccum = pa.dist
            } else {
                accumulatedAngle += pa.angle

                // Emit when the accumulated angle is large enough to be a real corner
                if abs(accumulatedAngle) >= mergeAngleWindow {
                    let instr = makeInstruction(
                        angle: accumulatedAngle,
                        distanceToTurn: segDistAccum,
                        coord: pa.coord,
                        index: pa.index
                    )
                    result.append(instr)
                    accumulatedAngle = 0
                    segDistAccum = 0
                    lastEmitCoord = pa.coord
                    lastEmitIndex = pa.index
                }
            }
        }

        // Emit any remaining significant accumulated angle
        if abs(accumulatedAngle) >= significanceThreshold {
            let lastCoord = pointAngles.last?.coord ?? coords[coords.count - 2]
            let lastIdx   = pointAngles.last?.index ?? coords.count - 2
            let instr = makeInstruction(
                angle: accumulatedAngle,
                distanceToTurn: segDistAccum,
                coord: lastCoord,
                index: lastIdx
            )
            result.append(instr)
        }

        // Finish instruction
        result.append(TurnInstruction(
            direction: .finish,
            distanceToTurn: segmentDist(coords[coords.count - 2], coords[coords.count - 1]),
            waypointCoordinate: coords[coords.count - 1],
            waypointIndex: coords.count - 1,
            rallySeverity: nil,
            rallyIsLeft: nil
        ))

        return result
    }

    /// Converts a signed accumulated angle into a `TurnInstruction`.
    private static func makeInstruction(angle: Double,
                                        distanceToTurn: Double,
                                        coord: CLLocationCoordinate2D,
                                        index: Int) -> TurnInstruction {
        let absAngle = abs(angle)
        let isLeft   = angle < 0
        let dir: TurnDirection
        let severity: Int

        switch absAngle {
        case 0..<15:
            dir      = isLeft ? .slightLeft  : .slightRight
            severity = 6
        case 15..<30:
            dir      = isLeft ? .slightLeft  : .slightRight
            severity = 5
        case 30..<55:
            dir      = isLeft ? .left        : .right
            severity = 4
        case 55..<90:
            dir      = isLeft ? .left        : .right
            severity = 3
        case 90..<130:
            dir      = isLeft ? .sharpLeft   : .sharpRight
            severity = 2
        default:
            dir      = isLeft ? .hairpinLeft : .hairpinRight
            severity = 1
        }

        return TurnInstruction(
            direction: dir,
            distanceToTurn: max(0, distanceToTurn),
            waypointCoordinate: coord,
            waypointIndex: index,
            rallySeverity: severity,
            rallyIsLeft: isLeft
        )
    }

    // MARK: - Geometry

    private static func bearing(from a: CLLocationCoordinate2D,
                                  to b: CLLocationCoordinate2D) -> Double {
        let φ1 = a.latitude  * .pi / 180
        let φ2 = b.latitude  * .pi / 180
        let Δλ = (b.longitude - a.longitude) * .pi / 180
        let y  = sin(Δλ) * cos(φ2)
        let x  = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        return atan2(y, x) * 180 / .pi
    }

    /// Normalises heading difference to –180…+180  (negative = left, positive = right).
    private static func normalise(_ deg: Double) -> Double {
        var a = deg.truncatingRemainder(dividingBy: 360)
        if a >  180 { a -= 360 }
        if a < -180 { a += 360 }
        return a
    }

    private static func segmentDist(_ a: CLLocationCoordinate2D,
                                     _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}
