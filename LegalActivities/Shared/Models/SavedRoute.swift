//
//  SavedRoute.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/12/25.
//

import Foundation
import CoreLocation

struct SavedRoute: Identifiable, Codable {
    let id: UUID
    var name: String
    var coordinates: [Coordinate] // Array of custom Coordinate struct
    var createdDate: Date
    var raceHistory: [RaceResult] = []

    struct Coordinate: Codable {
        var latitude: CLLocationDegrees
        var longitude: CLLocationDegrees
        init(_ coordinate: CLLocationCoordinate2D) { self.latitude = coordinate.latitude; self.longitude = coordinate.longitude }
        var clCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    }

    // Update initializer to include optional raceHistory
    init(id: UUID = UUID(), name: String, coordinates: [CLLocationCoordinate2D], createdDate: Date = Date(), raceHistory: [RaceResult] = []) {
        self.id = id
        self.name = name
        self.coordinates = coordinates.map(Coordinate.init)
        self.createdDate = createdDate
        self.raceHistory = raceHistory // Assign history
    }

    // Helper to get CLLocationCoordinate2D array easily
    var clCoordinates: [CLLocationCoordinate2D] {
        coordinates.map { $0.clCoordinate }
    }

    // Helper to get start/end coordinates if they exist
    var startCoordinate: CLLocationCoordinate2D? { clCoordinates.first }
    var endCoordinate: CLLocationCoordinate2D? { clCoordinates.last }
}
