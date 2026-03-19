//
//  FormatHelpersTests.swift
//  DownshiftTests
//
//  Tests for formatting utilities
//

import XCTest
@testable import Downshift

final class FormatHelpersTests: XCTestCase {
    
    // MARK: - formatDuration Tests
    
    func testFormatDuration_ZeroSeconds() {
        let result = formatDuration(0)
        XCTAssertEqual(result, "00:00:00")
    }
    
    func testFormatDuration_OneMinute() {
        let result = formatDuration(60)
        XCTAssertEqual(result, "00:01:00")
    }
    
    func testFormatDuration_OneHour() {
        let result = formatDuration(3600)
        XCTAssertEqual(result, "01:00:00")
    }
    
    func testFormatDuration_ComplexTime() {
        // 1 hour, 23 minutes, 45 seconds
        let result = formatDuration(5025)
        XCTAssertEqual(result, "01:23:45")
    }
    
    func testFormatDuration_UnderOneMinute() {
        let result = formatDuration(45)
        XCTAssertEqual(result, "00:00:45")
    }
    
    // MARK: - formatShortDuration Tests
    
    func testFormatShortDuration_ZeroSeconds() {
        let result = formatShortDuration(0)
        XCTAssertEqual(result, "0:00")
    }
    
    func testFormatShortDuration_UnderOneHour() {
        // 2 minutes, 5 seconds
        let result = formatShortDuration(125)
        XCTAssertEqual(result, "2:05")
    }
    
    func testFormatShortDuration_ExactlyOneHour() {
        let result = formatShortDuration(3600)
        XCTAssertEqual(result, "1:00:00")
    }
    
    func testFormatShortDuration_OverOneHour() {
        // 1 hour, 1 minute, 1 second
        let result = formatShortDuration(3661)
        XCTAssertEqual(result, "1:01:01")
    }
    
    func testFormatShortDuration_MultipleHours() {
        // 2 hours, 30 minutes, 15 seconds
        let result = formatShortDuration(9015)
        XCTAssertEqual(result, "2:30:15")
    }
}
