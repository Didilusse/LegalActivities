
//
//  User.swift
//  Downshift
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

// MARK: - Car Model for Garage
struct Car: Identifiable, Codable, Equatable {
    var id: UUID
    var make: String
    var model: String
    var year: Int
    var color: String
    var isPrimary: Bool
    
    init(
        id: UUID = UUID(),
        make: String,
        model: String,
        year: Int = Calendar.current.component(.year, from: Date()),
        color: String = "Silver",
        isPrimary: Bool = false
    ) {
        self.id = id
        self.make = make
        self.model = model
        self.year = year
        self.color = color
        self.isPrimary = isPrimary
    }
    
    var displayName: String {
        "\(year) \(make) \(model)"
    }
}

// Common car makes for picker
enum CarMake: String, CaseIterable {
    case acura = "Acura"
    case alfa = "Alfa Romeo"
    case aston = "Aston Martin"
    case audi = "Audi"
    case bentley = "Bentley"
    case bmw = "BMW"
    case bugatti = "Bugatti"
    case buick = "Buick"
    case cadillac = "Cadillac"
    case chevrolet = "Chevrolet"
    case chrysler = "Chrysler"
    case dodge = "Dodge"
    case ferrari = "Ferrari"
    case fiat = "Fiat"
    case ford = "Ford"
    case genesis = "Genesis"
    case gmc = "GMC"
    case honda = "Honda"
    case hyundai = "Hyundai"
    case infiniti = "Infiniti"
    case jaguar = "Jaguar"
    case jeep = "Jeep"
    case kia = "Kia"
    case lamborghini = "Lamborghini"
    case landRover = "Land Rover"
    case lexus = "Lexus"
    case lincoln = "Lincoln"
    case lotus = "Lotus"
    case maserati = "Maserati"
    case mazda = "Mazda"
    case mclaren = "McLaren"
    case mercedes = "Mercedes-Benz"
    case mini = "MINI"
    case mitsubishi = "Mitsubishi"
    case nissan = "Nissan"
    case porsche = "Porsche"
    case ram = "RAM"
    case rivian = "Rivian"
    case rollsRoyce = "Rolls-Royce"
    case subaru = "Subaru"
    case tesla = "Tesla"
    case toyota = "Toyota"
    case volkswagen = "Volkswagen"
    case volvo = "Volvo"
    case other = "Other"
}

// Common car colors
enum CarColor: String, CaseIterable {
    case white = "White"
    case black = "Black"
    case silver = "Silver"
    case gray = "Gray"
    case red = "Red"
    case blue = "Blue"
    case green = "Green"
    case yellow = "Yellow"
    case orange = "Orange"
    case brown = "Brown"
    case gold = "Gold"
    case other = "Other"
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
    var garage: [Car]

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
        rallyDirectionsEnabled: Bool = false,
        garage: [Car] = []
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
        self.garage = garage
    }
    
    var primaryCar: Car? {
        garage.first(where: { $0.isPrimary }) ?? garage.first
    }
}
