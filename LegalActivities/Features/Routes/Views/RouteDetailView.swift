//
//  RouteDetailView.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/12/25.
//


import SwiftUI
import MapKit

struct RouteDetailView: View {
    let route: SavedRoute
    @StateObject var locationManager = LocationManager() // Or inject if shared

    // State for the map display
    @State private var region = MKCoordinateRegion()
    @State private var routePolyline: MKPolyline?
    @State private var routeAnnotations: [LocationPin] = [] // Assuming LocationPin is defined
    @State private var isLoadingRoute = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { // Increased spacing slightly
                routeNameHeader // Extracted to computed property
                mapSection      // Extracted to computed property
                raceHistorySection // Extracted to computed property
                Spacer()        // Keep Spacer if you want button at bottom
                actionButtonSection // Extracted to computed property
            }
            .padding(.vertical) // Add some overall vertical padding
        }
        .navigationTitle(route.name) // Use route name for title
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupMapData()
        }
    }

    // MARK: - Computed View Properties for Breaking Down Complexity

    private var routeNameHeader: some View {
        Text(route.name)
            .font(.largeTitle)
            .fontWeight(.bold)
            .padding(.horizontal)
    }

    private var mapSection: some View {
        ZStack {
            DetailMapView( // Assuming DetailMapView is defined correctly
                region: $region,
                polyline: routePolyline,
                annotations: routeAnnotations
            )
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
            )
            
            if isLoadingRoute {
                ProgressView().controlSize(.large)
            }
        }
        .padding(.horizontal)
    }

    private var raceHistorySection: some View {
        Section { // Using Section for styling, ensure it's in a context that styles it (like List or Form, or just use VStack)
            VStack(alignment: .leading, spacing: 8) { // Use VStack if not in List/Form
                Text("Race History")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.bottom, 5)

                if route.raceHistory.isEmpty {
                    Text("No races recorded for this route yet.")
                        .foregroundColor(.secondary)
                        .padding(.vertical)
                } else {
                    ForEach(route.raceHistory.sorted(by: { $0.date > $1.date })) { result in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(result.date, style: .date)
                                Spacer()
                                Text("Time: \(formatDuration(result.totalDuration))")
                            }
                            if !result.lapDurations.isEmpty {
                                Text("Laps: " + result.lapDurations.map { formatDuration($0) }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Text(String(format: "Distance: %.2f km, Avg Speed: %.1f km/h", result.totalDistance / 1000, result.averageSpeed * 3.6))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var actionButtonSection: some View {
        NavigationLink(destination: RaceInProgressView(route: route, locationManager: locationManager)) {
            Text("Race This Route")
                .font(.headline)
                .foregroundColor(.white) // Ensure text is visible on button
                .frame(maxWidth: .infinity)
                .padding() // Ensure padding is inside the frame modification
                .background(Color.green) // Apply background to the frame/text content
                .cornerRadius(10)
        }
        // .buttonStyle(PrimaryRaceButton(color: .green)) // If PrimaryRaceButton handles frame and padding
        .padding() // Padding around the button/NavigationLink
    }


    // MARK: - Helper Functions (setupMapData, formatDuration as before)
    private func setupMapData() {
        let allCoordinates = route.clCoordinates
        guard !allCoordinates.isEmpty else { isLoadingRoute = false; return }
        isLoadingRoute = true

        var annotationsToAdd: [LocationPin] = []
        if let firstCoord = allCoordinates.first {
            annotationsToAdd.append(LocationPin(coordinate: firstCoord, type: .start))
        }
        if allCoordinates.count > 1, let lastCoord = allCoordinates.last, let firstCoord = allCoordinates.first, firstCoord != lastCoord {
            annotationsToAdd.append(LocationPin(coordinate: lastCoord, type: .end))
        }
        if allCoordinates.count > 2 {
            for i in 1..<(allCoordinates.count - 1) {
                annotationsToAdd.append(LocationPin(coordinate: allCoordinates[i], type: .checkpoint))
            }
        }
        self.routeAnnotations = annotationsToAdd

        guard let startCoord = allCoordinates.first,
              let endCoord = allCoordinates.last,
              allCoordinates.count > 1 else {
            if let singleCoord = allCoordinates.first {
                self.region = MKCoordinateRegion(center: singleCoord, latitudinalMeters: 1000, longitudinalMeters: 1000)
            }
            isLoadingRoute = false; return
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: startCoord))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: endCoord))
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            DispatchQueue.main.async {
                isLoadingRoute = false
                if let calculatedRoute = response?.routes.first {
                    self.routePolyline = calculatedRoute.polyline
                    if !calculatedRoute.polyline.boundingMapRect.isNull {
                        self.region = MKCoordinateRegion(calculatedRoute.polyline.boundingMapRect)
                    }
                } else {
                    print("Directions error or no route: \(error?.localizedDescription ?? "Unknown error")")
                    // Fallback to straight line polyline with all points
                    self.routePolyline = MKPolyline(coordinates: allCoordinates, count: allCoordinates.count)
                    if let polyline = self.routePolyline, !polyline.boundingMapRect.isNull {
                        self.region = MKCoordinateRegion(polyline.boundingMapRect)
                    }
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }
}
// MARK: - Detail Map View Bridge

// A simplified UIViewRepresentable for displaying the map in the detail view
struct DetailMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    var polyline: MKPolyline?
    var annotations: [LocationPin]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isUserInteractionEnabled = true // Allow basic interaction like zoom/pan
        mapView.showsUserLocation = false // Don't need user location dot here usually
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Update region
        // Only update region if it's significantly different to avoid jitter
        if uiView.region.center.latitude != region.center.latitude || uiView.region.span.latitudeDelta != region.span.latitudeDelta {
            uiView.setRegion(region, animated: true)
        }
        
        // Update annotations
        let oldAnnotations = uiView.annotations.compactMap { $0 as? LocationPin }
        uiView.removeAnnotations(oldAnnotations)
        uiView.addAnnotations(annotations)
        
        // Update polyline
        uiView.removeOverlays(uiView.overlays)
        if let polyline = polyline {
            uiView.addOverlay(polyline)
            // Adjust region once after polyline is added if needed (first time)
            if context.coordinator.needsRegionAdjustment {
                uiView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 30, left: 30, bottom: 30, right: 30), animated: true)
                context.coordinator.needsRegionAdjustment = false // Prevent constant readjustment
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var needsRegionAdjustment = true // Flag to set initial region based on polyline
        
        // Renderer for the polyline overlay
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue // Single color for detail view is fine
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        // View for annotations (Start/End pins)
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let locationPin = annotation as? LocationPin else { return nil }
            
            let reuseIdentifier = "detailAnnotation_\(locationPin.type)"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
            } else {
                annotationView?.annotation = annotation
            }
            
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.markerTintColor = UIColor(locationPin.type.markerColor)
                markerView.glyphImage = UIImage(systemName: locationPin.type.icon)
                // No glyph text needed usually for detail view start/end
            }
            return annotationView
        }
        // Reset flag when region changes manually or significantly
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // If user interacts, allow their region change to persist
            // needsRegionAdjustment = false // Could disable auto-adjust here
        }
    }
}


// MARK: - Coordinate Extension (Helper)
// Add this extension if not already globally available
// Allows comparing coordinates easily
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
