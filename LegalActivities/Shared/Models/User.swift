
//
//  User.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/12/25.
//

import Foundation
import CoreLocation

enum UnitPreference: String, Codable, CaseIterable {
    case metric
    case imperial

    var distanceUnit: String { self == .metric ? "km" : "mi" }
    var speedUnit: String { self == .metric ? "km/h" : "mph" }

    func formatDistance(_ meters: Double) -> String {
        if self == .metric {
            return String(format: "%.2f km", meters / 1000)
        } else {
            return String(format: "%.2f mi", meters / 1609.344)
        }
    }

    func formatSpeed(_ metersPerSecond: Double) -> String {
        if self == .metric {
            return String(format: "%.1f km/h", metersPerSecond * 3.6)
        } else {
            return String(format: "%.1f mph", metersPerSecond * 2.23694)
        }
    }
}

enum Difficulty: String, Codable, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var color: String {
        switch self {
        case .easy: return "green"
        case .medium: return "orange"
        case .hard: return "red"
        }
    }
}

struct UserProfile: Codable {
    var id: UUID
    var name: String
    var avatarSystemName: String
    var totalRaces: Int
    var totalDistance: Double  // meters
    var totalTime: TimeInterval
    var bestAvgSpeed: Double   // m/s
    var personalBests: [String: TimeInterval]  // routeId.uuidString: time
    var unitPreference: UnitPreference
    var isDarkMode: Bool
    var soundEnabled: Bool
    var hapticEnabled: Bool
    var rallyDirectionsEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String = "Racer",
        avatarSystemName: String = "person.circle.fill",
        totalRaces: Int = 0,
        totalDistance: Double = 0,
        totalTime: TimeInterval = 0,
        bestAvgSpeed: Double = 0,
        personalBests: [String: TimeInterval] = [:],
        unitPreference: UnitPreference = .imperial,
        isDarkMode: Bool = false,
        soundEnabled: Bool = true,
        hapticEnabled: Bool = true,
        rallyDirectionsEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.avatarSystemName = avatarSystemName
        self.totalRaces = totalRaces
        self.totalDistance = totalDistance
        self.totalTime = totalTime
        self.bestAvgSpeed = bestAvgSpeed
        self.personalBests = personalBests
        self.unitPreference = unitPreference
        self.isDarkMode = isDarkMode
        self.soundEnabled = soundEnabled
        self.hapticEnabled = hapticEnabled
        self.rallyDirectionsEnabled = rallyDirectionsEnabled
    }
}
