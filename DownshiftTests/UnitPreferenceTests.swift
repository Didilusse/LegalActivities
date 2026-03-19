//
//  UnitPreferenceTests.swift
//  DownshiftTests
//
//  Tests for UnitPreference formatting
//

import XCTest
@testable import Downshift

final class UnitPreferenceTests: XCTestCase {
    
    // MARK: - Distance Formatting Tests
    
    func testFormatDistance_Metric_Kilometers() {
        let preference = UnitPreference.metric
        let result = preference.formatDistance(1000)
        XCTAssertEqual(result, "1.00 km")
    }
    
    func testFormatDistance_Metric_LargeDistance() {
        let preference = UnitPreference.metric
        let result = preference.formatDistance(25000)
        XCTAssertEqual(result, "25.00 km")
    }
    
    func testFormatDistance_Metric_SmallDistance() {
        let preference = UnitPreference.metric
        let result = preference.formatDistance(500)
        XCTAssertEqual(result, "0.50 km")
    }
    
    func testFormatDistance_Imperial_Miles() {
        let preference = UnitPreference.imperial
        let result = preference.formatDistance(1609.344)
        XCTAssertEqual(result, "1.00 mi")
    }
    
    func testFormatDistance_Imperial_LargeDistance() {
        let preference = UnitPreference.imperial
        // 10 miles in meters
        let result = preference.formatDistance(16093.44)
        XCTAssertEqual(result, "10.00 mi")
    }
    
    func testFormatDistance_Imperial_SmallDistance() {
        let preference = UnitPreference.imperial
        // Half mile in meters
        let result = preference.formatDistance(804.672)
        XCTAssertEqual(result, "0.50 mi")
    }
    
    func testFormatDistance_Zero() {
        let metric = UnitPreference.metric
        let imperial = UnitPreference.imperial
        
        XCTAssertEqual(metric.formatDistance(0), "0.00 km")
        XCTAssertEqual(imperial.formatDistance(0), "0.00 mi")
    }
    
    // MARK: - Speed Formatting Tests
    
    func testFormatSpeed_Metric_KmPerHour() {
        let preference = UnitPreference.metric
        // 10 m/s = 36 km/h
        let result = preference.formatSpeed(10)
        XCTAssertEqual(result, "36.0 km/h")
    }
    
    func testFormatSpeed_Metric_HighSpeed() {
        let preference = UnitPreference.metric
        // 27.778 m/s = ~100 km/h
        let result = preference.formatSpeed(27.778)
        XCTAssertEqual(result, "100.0 km/h")
    }
    
    func testFormatSpeed_Imperial_MilesPerHour() {
        let preference = UnitPreference.imperial
        // 10 m/s = ~22.4 mph
        let result = preference.formatSpeed(10)
        XCTAssertEqual(result, "22.4 mph")
    }
    
    func testFormatSpeed_Imperial_HighSpeed() {
        let preference = UnitPreference.imperial
        // 44.704 m/s = ~100 mph
        let result = preference.formatSpeed(44.704)
        XCTAssertEqual(result, "100.0 mph")
    }
    
    func testFormatSpeed_Zero() {
        let metric = UnitPreference.metric
        let imperial = UnitPreference.imperial
        
        XCTAssertEqual(metric.formatSpeed(0), "0.0 km/h")
        XCTAssertEqual(imperial.formatSpeed(0), "0.0 mph")
    }
    
    // MARK: - Unit Property Tests
    
    func testDistanceUnit_Metric() {
        XCTAssertEqual(UnitPreference.metric.distanceUnit, "km")
    }
    
    func testDistanceUnit_Imperial() {
        XCTAssertEqual(UnitPreference.imperial.distanceUnit, "mi")
    }
    
    func testSpeedUnit_Metric() {
        XCTAssertEqual(UnitPreference.metric.speedUnit, "km/h")
    }
    
    func testSpeedUnit_Imperial() {
        XCTAssertEqual(UnitPreference.imperial.speedUnit, "mph")
    }
    
    // MARK: - Codable Tests
    
    func testCodable_Metric() throws {
        let preference = UnitPreference.metric
        let encoded = try JSONEncoder().encode(preference)
        let decoded = try JSONDecoder().decode(UnitPreference.self, from: encoded)
        
        XCTAssertEqual(decoded, preference)
    }
    
    func testCodable_Imperial() throws {
        let preference = UnitPreference.imperial
        let encoded = try JSONEncoder().encode(preference)
        let decoded = try JSONDecoder().decode(UnitPreference.self, from: encoded)
        
        XCTAssertEqual(decoded, preference)
    }
}
