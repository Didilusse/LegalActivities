//
//  UserProfileTests.swift
//  DownshiftTests
//
//  Tests for UserProfile and Car models
//

import XCTest
@testable import Downshift

final class UserProfileTests: XCTestCase {
    
    // MARK: - UserProfile Initialization Tests
    
    func testUserProfile_DefaultInitialization() {
        let profile = UserProfile()
        
        XCTAssertEqual(profile.name, "Racer")
        XCTAssertEqual(profile.totalRaces, 0)
        XCTAssertEqual(profile.totalDistance, 0)
        XCTAssertEqual(profile.totalTime, 0)
        XCTAssertEqual(profile.bestAvgSpeed, 0)
        XCTAssertEqual(profile.unitPreference, .imperial)
        XCTAssertTrue(profile.soundEnabled)
        XCTAssertTrue(profile.hapticEnabled)
        XCTAssertFalse(profile.rallyDirectionsEnabled)
        XCTAssertTrue(profile.garage.isEmpty)
    }
    
    func testUserProfile_CustomInitialization() {
        let profile = UserProfile(
            name: "Test Driver",
            totalRaces: 10,
            totalDistance: 50000,
            unitPreference: .metric
        )
        
        XCTAssertEqual(profile.name, "Test Driver")
        XCTAssertEqual(profile.totalRaces, 10)
        XCTAssertEqual(profile.totalDistance, 50000)
        XCTAssertEqual(profile.unitPreference, .metric)
    }
    
    // MARK: - Primary Car Tests
    
    func testPrimaryCar_WhenNoCars() {
        let profile = UserProfile()
        XCTAssertNil(profile.primaryCar)
    }
    
    func testPrimaryCar_WhenOnlyOneCar() {
        let car = Car(make: "Toyota", model: "GR86", isPrimary: false)
        let profile = UserProfile(garage: [car])
        
        XCTAssertNotNil(profile.primaryCar)
        XCTAssertEqual(profile.primaryCar?.make, "Toyota")
    }
    
    func testPrimaryCar_ReturnsPrimaryWhenSet() {
        let car1 = Car(make: "Honda", model: "Civic", isPrimary: false)
        let car2 = Car(make: "Subaru", model: "WRX", isPrimary: true)
        let car3 = Car(make: "Mazda", model: "Miata", isPrimary: false)
        let profile = UserProfile(garage: [car1, car2, car3])
        
        XCTAssertNotNil(profile.primaryCar)
        XCTAssertEqual(profile.primaryCar?.make, "Subaru")
        XCTAssertEqual(profile.primaryCar?.model, "WRX")
    }
    
    func testPrimaryCar_ReturnsFirstWhenNoPrimarySet() {
        let car1 = Car(make: "Ford", model: "Mustang", isPrimary: false)
        let car2 = Car(make: "Chevrolet", model: "Camaro", isPrimary: false)
        let profile = UserProfile(garage: [car1, car2])
        
        XCTAssertNotNil(profile.primaryCar)
        XCTAssertEqual(profile.primaryCar?.make, "Ford")
    }
    
    // MARK: - UserProfile Codable Tests
    
    func testUserProfile_Codable() throws {
        let car = Car(make: "Nissan", model: "GT-R", year: 2024, isPrimary: true)
        let profile = UserProfile(
            name: "Test Racer",
            totalRaces: 5,
            totalDistance: 25000,
            unitPreference: .metric,
            garage: [car]
        )
        
        let encoded = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: encoded)
        
        XCTAssertEqual(decoded.name, profile.name)
        XCTAssertEqual(decoded.totalRaces, profile.totalRaces)
        XCTAssertEqual(decoded.totalDistance, profile.totalDistance)
        XCTAssertEqual(decoded.unitPreference, profile.unitPreference)
        XCTAssertEqual(decoded.garage.count, 1)
        XCTAssertEqual(decoded.garage.first?.make, "Nissan")
    }
}

// MARK: - Car Tests

final class CarTests: XCTestCase {
    
    func testCar_DefaultInitialization() {
        let currentYear = Calendar.current.component(.year, from: Date())
        let car = Car(make: "BMW", model: "M3")
        
        XCTAssertEqual(car.make, "BMW")
        XCTAssertEqual(car.model, "M3")
        XCTAssertEqual(car.year, currentYear)
        XCTAssertEqual(car.color, "Silver")
        XCTAssertFalse(car.isPrimary)
    }
    
    func testCar_CustomInitialization() {
        let car = Car(
            make: "Porsche",
            model: "911 GT3",
            year: 2023,
            color: "Red",
            isPrimary: true
        )
        
        XCTAssertEqual(car.make, "Porsche")
        XCTAssertEqual(car.model, "911 GT3")
        XCTAssertEqual(car.year, 2023)
        XCTAssertEqual(car.color, "Red")
        XCTAssertTrue(car.isPrimary)
    }
    
    func testCar_DisplayName() {
        let car = Car(make: "Tesla", model: "Model 3", year: 2024)
        XCTAssertEqual(car.displayName, "2024 Tesla Model 3")
    }
    
    func testCar_Equatable() {
        let id = UUID()
        let car1 = Car(id: id, make: "Audi", model: "RS3")
        let car2 = Car(id: id, make: "BMW", model: "M2") // Same ID, different data
        
        XCTAssertEqual(car1, car2) // Should be equal because same ID
    }
    
    func testCar_NotEquatable() {
        let car1 = Car(make: "Mercedes", model: "AMG GT")
        let car2 = Car(make: "Mercedes", model: "AMG GT")
        
        XCTAssertNotEqual(car1, car2) // Different IDs
    }
    
    func testCar_Codable() throws {
        let car = Car(
            make: "Lamborghini",
            model: "Huracán",
            year: 2025,
            color: "Yellow",
            isPrimary: true
        )
        
        let encoded = try JSONEncoder().encode(car)
        let decoded = try JSONDecoder().decode(Car.self, from: encoded)
        
        XCTAssertEqual(decoded.id, car.id)
        XCTAssertEqual(decoded.make, car.make)
        XCTAssertEqual(decoded.model, car.model)
        XCTAssertEqual(decoded.year, car.year)
        XCTAssertEqual(decoded.color, car.color)
        XCTAssertEqual(decoded.isPrimary, car.isPrimary)
    }
}

// MARK: - Difficulty Tests

final class DifficultyTests: XCTestCase {
    
    func testDifficulty_AllCases() {
        let difficulties = Difficulty.allCases
        XCTAssertEqual(difficulties.count, 3)
        XCTAssertTrue(difficulties.contains(.easy))
        XCTAssertTrue(difficulties.contains(.medium))
        XCTAssertTrue(difficulties.contains(.hard))
    }
    
    func testDifficulty_RawValues() {
        XCTAssertEqual(Difficulty.easy.rawValue, "Easy")
        XCTAssertEqual(Difficulty.medium.rawValue, "Medium")
        XCTAssertEqual(Difficulty.hard.rawValue, "Hard")
    }
    
    func testDifficulty_Colors() {
        XCTAssertEqual(Difficulty.easy.color, "green")
        XCTAssertEqual(Difficulty.medium.color, "orange")
        XCTAssertEqual(Difficulty.hard.color, "red")
    }
    
    func testDifficulty_Codable() throws {
        let difficulty = Difficulty.medium
        let encoded = try JSONEncoder().encode(difficulty)
        let decoded = try JSONDecoder().decode(Difficulty.self, from: encoded)
        
        XCTAssertEqual(decoded, difficulty)
    }
}

// MARK: - CarMake Tests

final class CarMakeTests: XCTestCase {
    
    func testCarMake_PopularBrands() {
        XCTAssertEqual(CarMake.toyota.rawValue, "Toyota")
        XCTAssertEqual(CarMake.honda.rawValue, "Honda")
        XCTAssertEqual(CarMake.ford.rawValue, "Ford")
        XCTAssertEqual(CarMake.bmw.rawValue, "BMW")
        XCTAssertEqual(CarMake.mercedes.rawValue, "Mercedes-Benz")
        XCTAssertEqual(CarMake.porsche.rawValue, "Porsche")
        XCTAssertEqual(CarMake.ferrari.rawValue, "Ferrari")
        XCTAssertEqual(CarMake.lamborghini.rawValue, "Lamborghini")
    }
    
    func testCarMake_AllCasesCount() {
        let makes = CarMake.allCases
        // Should have all the car makes including "Other"
        XCTAssertGreaterThan(makes.count, 20)
    }
    
    func testCarMake_ContainsOther() {
        XCTAssertEqual(CarMake.other.rawValue, "Other")
    }
}

// MARK: - CarColor Tests

final class CarColorTests: XCTestCase {
    
    func testCarColor_CommonColors() {
        XCTAssertEqual(CarColor.white.rawValue, "White")
        XCTAssertEqual(CarColor.black.rawValue, "Black")
        XCTAssertEqual(CarColor.silver.rawValue, "Silver")
        XCTAssertEqual(CarColor.red.rawValue, "Red")
        XCTAssertEqual(CarColor.blue.rawValue, "Blue")
    }
    
    func testCarColor_AllCasesCount() {
        let colors = CarColor.allCases
        XCTAssertGreaterThan(colors.count, 10)
    }
    
    func testCarColor_ContainsOther() {
        XCTAssertEqual(CarColor.other.rawValue, "Other")
    }
}
