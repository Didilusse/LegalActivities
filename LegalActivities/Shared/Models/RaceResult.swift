//
//  RaceResult.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/12/25.
//

import Foundation
import CoreLocation

struct RaceResult: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let totalDuration: TimeInterval
    let lapDurations: [TimeInterval]
    let totalDistance: Double
    let averageSpeed: Double

    init(id: UUID = UUID(),
         date: Date = Date(),
         totalDuration: TimeInterval,
         lapDurations: [TimeInterval],
         totalDistance: Double,
         averageSpeed: Double) {
        self.id = id
        self.date = date
        self.totalDuration = totalDuration
        self.lapDurations = lapDurations
        self.totalDistance = totalDistance
        self.averageSpeed = averageSpeed
    }
}
