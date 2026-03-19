//
//  RaceResultTests.swift
//  DownshiftTests
//
//  Tests for RaceResult model
//

import XCTest
@testable import Downshift

final class RaceResultTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testRaceResult_BasicInitialization() {
        let result = RaceResult(
            totalDuration: 120.0,
            lapDurations: [60.0, 60.0],
            totalDistance: 5000.0,
            averageSpeed: 15.0
        )
        
        XCTAssertEqual(result.totalDuration, 120.0)
        XCTAssertEqual(result.lapDurations.count, 2)
        XCTAssertEqual(result.totalDistance, 5000.0)
        XCTAssertEqual(result.averageSpeed, 15.0)
    }
    
    func testRaceResult_WithCustomDate() {
        let customDate = Date(timeIntervalSince1970: 1609459200) // Jan 1, 2021
        let result = RaceResult(
            date: customDate,
            totalDuration: 100.0,
            lapDurations: [100.0],
            totalDistance: 1000.0,
            averageSpeed: 10.0
        )
        
        XCTAssertEqual(result.date, customDate)
    }
    
    func testRaceResult_WithMultipleLaps() {
        let lapDurations = [45.5, 42.3, 43.8, 44.2]
        let result = RaceResult(
            totalDuration: 175.8,
            lapDurations: lapDurations,
            totalDistance: 8000.0,
            averageSpeed: 20.0
        )
        
        XCTAssertEqual(result.lapDurations.count, 4)
        XCTAssertEqual(result.lapDurations, lapDurations)
    }
    
    // MARK: - Edge Cases
    
    func testRaceResult_ZeroDuration() {
        let result = RaceResult(
            totalDuration: 0,
            lapDurations: [],
            totalDistance: 0,
            averageSpeed: 0
        )
        
        XCTAssertEqual(result.totalDuration, 0)
        XCTAssertTrue(result.lapDurations.isEmpty)
        XCTAssertEqual(result.averageSpeed, 0)
    }
    
    func testRaceResult_SingleLap() {
        let result = RaceResult(
            totalDuration: 65.5,
            lapDurations: [65.5],
            totalDistance: 2500.0,
            averageSpeed: 12.5
        )
        
        XCTAssertEqual(result.lapDurations.count, 1)
        XCTAssertEqual(result.lapDurations.first, 65.5)
    }
    
    func testRaceResult_LargeDistance() {
        let result = RaceResult(
            totalDuration: 3600.0,
            lapDurations: [1800.0, 1800.0],
            totalDistance: 100000.0, // 100 km
            averageSpeed: 27.78 // ~100 km/h
        )
        
        XCTAssertEqual(result.totalDistance, 100000.0)
        XCTAssertEqual(result.averageSpeed, 27.78, accuracy: 0.01)
    }
    
    // MARK: - Identifiable Tests
    
    func testRaceResult_HasUniqueID() {
        let result1 = RaceResult(
            totalDuration: 100,
            lapDurations: [100],
            totalDistance: 1000,
            averageSpeed: 10
        )
        let result2 = RaceResult(
            totalDuration: 100,
            lapDurations: [100],
            totalDistance: 1000,
            averageSpeed: 10
        )
        
        XCTAssertNotEqual(result1.id, result2.id)
    }
    
    func testRaceResult_IDPersists() {
        let id = UUID()
        let result = RaceResult(
            id: id,
            totalDuration: 100,
            lapDurations: [100],
            totalDistance: 1000,
            averageSpeed: 10
        )
        
        XCTAssertEqual(result.id, id)
    }
    
    // MARK: - Hashable Tests
    
    func testRaceResult_Hashable() {
        let result = RaceResult(
            totalDuration: 100,
            lapDurations: [50, 50],
            totalDistance: 2000,
            averageSpeed: 20
        )
        
        var set = Set<RaceResult>()
        set.insert(result)
        
        XCTAssertTrue(set.contains(result))
        XCTAssertEqual(set.count, 1)
    }
    
    func testRaceResult_HashableUnique() {
        let result1 = RaceResult(
            totalDuration: 100,
            lapDurations: [100],
            totalDistance: 1000,
            averageSpeed: 10
        )
        let result2 = RaceResult(
            totalDuration: 100,
            lapDurations: [100],
            totalDistance: 1000,
            averageSpeed: 10
        )
        
        var set = Set<RaceResult>()
        set.insert(result1)
        set.insert(result2)
        
        // Both should be in set because different IDs
        XCTAssertEqual(set.count, 2)
    }
    
    // MARK: - Codable Tests
    
    func testRaceResult_Codable() throws {
        let originalDate = Date()
        let result = RaceResult(
            date: originalDate,
            totalDuration: 150.5,
            lapDurations: [50.5, 50.0, 50.0],
            totalDistance: 7500.0,
            averageSpeed: 18.5
        )
        
        let encoded = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(RaceResult.self, from: encoded)
        
        XCTAssertEqual(decoded.id, result.id)
        XCTAssertEqual(decoded.date.timeIntervalSince1970, result.date.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decoded.totalDuration, result.totalDuration)
        XCTAssertEqual(decoded.lapDurations, result.lapDurations)
        XCTAssertEqual(decoded.totalDistance, result.totalDistance)
        XCTAssertEqual(decoded.averageSpeed, result.averageSpeed)
    }
    
    func testRaceResult_JSONEncoding() throws {
        let result = RaceResult(
            totalDuration: 200.0,
            lapDurations: [100.0, 100.0],
            totalDistance: 10000.0,
            averageSpeed: 25.0
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(result)
        let jsonString = String(data: jsonData, encoding: .utf8)
        
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString!.contains("totalDuration"))
        XCTAssertTrue(jsonString!.contains("lapDurations"))
        XCTAssertTrue(jsonString!.contains("totalDistance"))
        XCTAssertTrue(jsonString!.contains("averageSpeed"))
    }
    
    // MARK: - Performance Tests
    
    func testRaceResult_FastestLap() {
        let lapDurations = [62.5, 58.3, 59.1, 57.8, 60.2]
        let result = RaceResult(
            totalDuration: lapDurations.reduce(0, +),
            lapDurations: lapDurations,
            totalDistance: 15000.0,
            averageSpeed: 22.0
        )
        
        let fastestLap = result.lapDurations.min()
        XCTAssertEqual(fastestLap, 57.8)
    }
    
    func testRaceResult_SlowestLap() {
        let lapDurations = [62.5, 58.3, 59.1, 57.8, 60.2]
        let result = RaceResult(
            totalDuration: lapDurations.reduce(0, +),
            lapDurations: lapDurations,
            totalDistance: 15000.0,
            averageSpeed: 22.0
        )
        
        let slowestLap = result.lapDurations.max()
        XCTAssertEqual(slowestLap, 62.5)
    }
    
    func testRaceResult_AverageLapTime() {
        let lapDurations = [60.0, 60.0, 60.0]
        let result = RaceResult(
            totalDuration: 180.0,
            lapDurations: lapDurations,
            totalDistance: 9000.0,
            averageSpeed: 16.67
        )
        
        let avgLapTime = result.lapDurations.reduce(0, +) / Double(result.lapDurations.count)
        XCTAssertEqual(avgLapTime, 60.0)
    }
}
