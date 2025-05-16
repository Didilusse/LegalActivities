//
//  RaceLiveMapViewBridge.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/16/25.
//


import SwiftUI
import MapKit

struct RaceLiveMapViewBridge: UIViewRepresentable {
    @Binding var mapView: MKMapView
    @Binding var region: MKCoordinateRegion
    let routeToDisplay: SavedRoute?
    let nextTargetCoordinate: CLLocationCoordinate2D?
    let currentRaceState: RaceState
    
    func makeUIView(context: Context) -> MKMapView {
        
        self.mapView.delegate = context.coordinator // Use the bound mapView
        self.mapView.showsUserLocation = true
        self.mapView.userTrackingMode = .followWithHeading
        return self.mapView // Return the bound instance
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        if uiView.userTrackingMode == .none { // Allow user to pan away
            // Only update programmatically set region if it truly changed
            // to avoid fighting with user interaction or minor updates.
            let regionChangedSignificantly = abs(uiView.region.center.latitude - region.center.latitude) > 0.0001 ||
            abs(uiView.region.center.longitude - region.center.longitude) > 0.0001 ||
            abs(uiView.region.span.latitudeDelta - region.span.latitudeDelta) > 0.0001 ||
            abs(uiView.region.span.longitudeDelta - region.span.longitudeDelta) > 0.0001
            if regionChangedSignificantly {
                uiView.setRegion(region, animated: true)
            }
        }
        
        let oldAnnotations = uiView.annotations.filter { !($0 is MKUserLocation) }
        uiView.removeAnnotations(oldAnnotations)
        uiView.removeOverlays(uiView.overlays) // Clear all previous overlays
        
        guard let route = routeToDisplay else { return }
        
        // Add route polyline for the entire route
        if route.clCoordinates.count > 1 {
            let polyline = MKPolyline(coordinates: route.clCoordinates, count: route.clCoordinates.count)
            uiView.addOverlay(polyline, level: .aboveRoads)
        }
        
        // Add annotations for start, end, and checkpoints
        var pinsToAdd: [LocationPin] = []
        if let start = route.startCoordinate {
            let startPin = LocationPin(coordinate: start, type: .start)
            pinsToAdd.append(startPin)
        }
        
        if route.clCoordinates.count > 2 { // Checkpoints exist
            for i in 1..<(route.clCoordinates.count - 1) {
                let cpCoord = route.clCoordinates[i]
                let checkpointPin = LocationPin(coordinate: cpCoord, type: .checkpoint)
                let isNextTarget = (cpCoord.latitude == nextTargetCoordinate?.latitude &&
                                    cpCoord.longitude == nextTargetCoordinate?.longitude)
                checkpointPin.isNext = isNextTarget // Set the property after init
                pinsToAdd.append(checkpointPin)
            }
        }
        
        if let end = route.endCoordinate, (route.clCoordinates.count == 1 || end != route.startCoordinate) {
            let endPin = LocationPin(coordinate: end, type: .end)
            pinsToAdd.append(endPin)
        }
        uiView.addAnnotations(pinsToAdd)
        
        // Fit map to route on initial load if not actively tracking with heading
        if context.coordinator.isInitialLoad && route.clCoordinates.count > 1 {
            if uiView.userTrackingMode == .none { // Only fit if not already following
                let fittingRect = MKPolyline(coordinates: route.clCoordinates, count: route.clCoordinates.count).boundingMapRect
                if !fittingRect.isNull {
                    uiView.setVisibleMapRect(fittingRect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50), animated: true)
                }
            }
            context.coordinator.isInitialLoad = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RaceLiveMapViewBridge
        var isInitialLoad = true
        
        init(_ parent: RaceLiveMapViewBridge) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemGray.withAlphaComponent(0.7)
                renderer.lineWidth = 4
                renderer.lineDashPattern = [2, 6]
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            guard let locationPin = annotation as? LocationPin else { return nil }
            
            let reuseId = "racePin_\(locationPin.type.hashValue)_\(locationPin.id)" // More unique reuse ID
            var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKMarkerAnnotationView
            if pinView == nil {
                pinView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            } else {
                pinView?.annotation = annotation // Ensure annotation is updated for reused views
            }
            
            guard let markerPinView = pinView else { return nil } // Ensure pinView is not nil
            
            markerPinView.canShowCallout = false
            markerPinView.markerTintColor = UIColor(locationPin.type.markerColor)
            markerPinView.glyphImage = UIImage(systemName: locationPin.type.icon)
            
            if locationPin.isNext ?? false {
                markerPinView.markerTintColor = .orange
                markerPinView.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                markerPinView.zPriority = .max
            } else {
                markerPinView.transform = .identity
                markerPinView.zPriority = .defaultUnselected // Default for non-next pins
            }
            
            // Access currentRaceState from parent (RaceLiveMapViewBridge)
            // This is line 138 (approximately) where the error was occurring
            if locationPin.type == .start && parent.currentRaceState == .inProgress {
                markerPinView.alpha = 0.4 // Make start pin less prominent during race
            } else {
                markerPinView.alpha = 1.0
            }
            
            return markerPinView
        }
        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            print("Map tracking mode changed to: \(mode.rawValue)")
            // If mode becomes .none because user interacted, parent view could show a recenter button
            if mode == .none && parent.currentRaceState == .inProgress { // Use your enum
                // parent.showRecenterButton = true // Example: update a binding
            } else {
                // parent.showRecenterButton = false
            }
        }
        
    }
}
