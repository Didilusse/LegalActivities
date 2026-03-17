//
//  SavedRoute.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/12/25.
//

import Foundation
import CoreLocation

struct SavedRoute: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var coordinates: [Coordinate] // Array of custom Coordinate struct
    var createdDate: Date
    var raceHistory: [RaceResult] = []
    var difficulty: Difficulty = .medium
    var tags: [String] = []

    struct Coordinate: Codable {
        var latitude: CLLocationDegrees
        var longitude: CLLocationDegrees
        init(_ coordinate: CLLocationCoordinate2D) { self.latitude = coordinate.latitude; self.longitude = coordinate.longitude }
        var clCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    }

    init(id: UUID = UUID(), name: String, coordinates: [CLLocationCoordinate2D], createdDate: Date = Date(), raceHistory: [RaceResult] = [], difficulty: Difficulty = .medium, tags: [String] = []) {
        self.id = id
        self.name = name
        self.coordinates = coordinates.map(Coordinate.init)
        self.createdDate = createdDate
        self.raceHistory = raceHistory
        self.difficulty = difficulty
        self.tags = tags
    }

    // Helper to get CLLocationCoordinate2D array easily
    var clCoordinates: [CLLocationCoordinate2D] {
        coordinates.map { $0.clCoordinate }
    }

    // Helper to get start/end coordinates if they exist
    var startCoordinate: CLLocationCoordinate2D? { clCoordinates.first }
    var endCoordinate: CLLocationCoordinate2D? { clCoordinates.last }

    /// Straight-line sum of all coordinate-to-coordinate distances in metres.
    var totalDistance: Double {
        let coords = clCoordinates
        guard coords.count >= 2 else { return 0 }
        var total = 0.0
        for i in 0..<coords.count - 1 {
            let a = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            let b = CLLocation(latitude: coords[i+1].latitude, longitude: coords[i+1].longitude)
            total += a.distance(from: b)
        }
        return total
    }

    /// Estimated duration in seconds, assuming ~40 km/h average speed.
    var estimatedDuration: TimeInterval {
        totalDistance / (40_000 / 3600)
    }

    // Hashable conformance based on id only
    static func == (lhs: SavedRoute, rhs: SavedRoute) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
