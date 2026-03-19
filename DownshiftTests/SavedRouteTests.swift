//
//  SavedRouteTests.swift
//  DownshiftTests
//
//  Tests for SavedRoute model
//

import XCTest
import CoreLocation
@testable import Downshift

final class SavedRouteTests: XCTestCase {
    
    // MARK: - Distance Calculation Tests
    
    func testTotalDistance_EmptyCoordinates() {
        let route = SavedRoute(name: "Empty Route", coordinates: [])
        XCTAssertEqual(route.totalDistance, 0)
    }
    
    func testTotalDistance_SingleCoordinate() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let route = SavedRoute(name: "Single Point", coordinates: [coord])
        XCTAssertEqual(route.totalDistance, 0)
    }
    
    func testTotalDistance_TwoCoordinates() {
        // San Francisco to Oakland (approx 13.5 km straight line)
        let sf = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let oakland = CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2712)
        let route = SavedRoute(name: "SF to Oakland", coordinates: [sf, oakland])
        
        // Distance should be approximately 13.5 km (13500 meters)
        // Allow 1km tolerance for calculation differences
        XCTAssertGreaterThan(route.totalDistance, 12500)
        XCTAssertLessThan(route.totalDistance, 14500)
    }
    
    func testTotalDistance_MultipleCoordinates() {
        let coords = [
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
            CLLocationCoordinate2D(latitude: 37.7949, longitude: -122.3994)
        ]
        let route = SavedRoute(name: "Multi Point", coordinates: coords)
        
        // Should be sum of all segments
        XCTAssertGreaterThan(route.totalDistance, 0)
    }
    
    // MARK: - Estimated Duration Tests
    
    func testEstimatedDuration_EmptyRoute() {
        let route = SavedRoute(name: "Empty", coordinates: [])
        XCTAssertEqual(route.estimatedDuration, 0)
    }
    
    func testEstimatedDuration_WithDistance() {
        // Create a route with known distance
        // Assuming 40 km/h average speed: 10km should take 900 seconds (15 min)
        let sf = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let distant = CLLocationCoordinate2D(latitude: 37.8644, longitude: -122.2994)
        let route = SavedRoute(name: "Test Route", coordinates: [sf, distant])
        
        // Duration should be proportional to distance at 40 km/h
        let expectedDuration = route.totalDistance / (40_000 / 3600)
        XCTAssertEqual(route.estimatedDuration, expectedDuration, accuracy: 0.01)
    }
    
    // MARK: - Coordinate Helper Tests
    
    func testStartCoordinate() {
        let start = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let end = CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2712)
        let route = SavedRoute(name: "Test", coordinates: [start, end])
        
        XCTAssertNotNil(route.startCoordinate)
        XCTAssertEqual(route.startCoordinate?.latitude, start.latitude)
        XCTAssertEqual(route.startCoordinate?.longitude, start.longitude)
    }
    
    func testEndCoordinate() {
        let start = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let end = CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2712)
        let route = SavedRoute(name: "Test", coordinates: [start, end])
        
        XCTAssertNotNil(route.endCoordinate)
        XCTAssertEqual(route.endCoordinate?.latitude, end.latitude)
        XCTAssertEqual(route.endCoordinate?.longitude, end.longitude)
    }
    
    func testStartCoordinate_EmptyRoute() {
        let route = SavedRoute(name: "Empty", coordinates: [])
        XCTAssertNil(route.startCoordinate)
    }
    
    func testEndCoordinate_EmptyRoute() {
        let route = SavedRoute(name: "Empty", coordinates: [])
        XCTAssertNil(route.endCoordinate)
    }
    
    // MARK: - Reversed Copy Tests
    
    func testReversedCopy_CoordinatesReversed() {
        let start = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let middle = CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)
        let end = CLLocationCoordinate2D(latitude: 37.7949, longitude: -122.3994)
        let route = SavedRoute(name: "Original", coordinates: [start, middle, end])
        
        let reversed = route.reversedCopy()
        
        XCTAssertEqual(reversed.clCoordinates.count, 3)
        XCTAssertEqual(reversed.startCoordinate?.latitude, end.latitude)
        XCTAssertEqual(reversed.endCoordinate?.latitude, start.latitude)
    }
    
    func testReversedCopy_KeepsSameID() {
        let coords = [
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2712)
        ]
        let route = SavedRoute(name: "Test", coordinates: coords)
        let reversed = route.reversedCopy()
        
        XCTAssertEqual(reversed.id, route.id)
    }
    
    func testReversedCopy_KeepsMetadata() {
        let coords = [
            CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2712)
        ]
        let route = SavedRoute(
            name: "Test Route",
            coordinates: coords,
            tags: ["scenic", "challenging"],
            location: "San Francisco"
        )
        let reversed = route.reversedCopy()
        
        XCTAssertEqual(reversed.name, route.name)
        XCTAssertEqual(reversed.tags, route.tags)
        XCTAssertEqual(reversed.location, route.location)
        XCTAssertEqual(reversed.difficulty, route.difficulty)
    }
    
    // MARK: - Equatable Tests
    
    func testEquality_SameID() {
        let id = UUID()
        let coords = [CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)]
        let route1 = SavedRoute(id: id, name: "Route 1", coordinates: coords)
        let route2 = SavedRoute(id: id, name: "Route 2", coordinates: coords)
        
        // Should be equal because they have the same ID
        XCTAssertEqual(route1, route2)
    }
    
    func testEquality_DifferentID() {
        let coords = [CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)]
        let route1 = SavedRoute(name: "Route 1", coordinates: coords)
        let route2 = SavedRoute(name: "Route 1", coordinates: coords)
        
        // Should NOT be equal because they have different IDs
        XCTAssertNotEqual(route1, route2)
    }
}
