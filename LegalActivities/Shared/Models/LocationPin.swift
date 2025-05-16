//
//  LocationPin.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/12/25.
//
import MapKit
import SwiftUI

class LocationPin: NSObject, MKAnnotation, Identifiable {
    let id = UUID()
    
    // MKAnnotation requirements
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String? {
        switch type {
        case .start: return "Start Point"
        case .checkpoint: return "Checkpoint"
        case .end: return "End Point"
        }
    }
    
    // Custom properties
    let type: PointType
    var isNext: Bool? = false
    init(coordinate: CLLocationCoordinate2D, type: PointType) {
        self.coordinate = coordinate
        self.type = type
    }
    
    enum PointType {
        case start, checkpoint, end
        
        var markerColor: Color {
            switch self {
            case .start: return .green
            case .checkpoint: return .blue
            case .end: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .start: return "flag.fill"
            case .checkpoint: return "mappin.circle.fill"
            case .end: return "flag.checkered"
            }
        }
    }
}
