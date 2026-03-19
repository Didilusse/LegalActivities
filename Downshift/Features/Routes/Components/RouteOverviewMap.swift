//
//  RouteOverviewMap.swift
//  Downshift
//
//  A static, non-interactive map snapshot showing a saved route's path
//  with start/end pins. Used for route previews.
//

import SwiftUI
import MapKit

struct RouteOverviewMap: UIViewRepresentable {
    let route: SavedRoute

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsUserLocation = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)

        let coords = route.clCoordinates
        guard coords.count >= 2 else { return }

        // Draw the route polyline
        let polyline = MKPolyline(coordinates: coords, count: coords.count)
        mapView.addOverlay(polyline, level: .aboveRoads)

        // Start pin
        let startPin = MKPointAnnotation()
        startPin.coordinate = coords.first!
        startPin.title = "Start"
        mapView.addAnnotation(startPin)

        // End pin (only if different from start)
        if coords.last!.latitude != coords.first!.latitude ||
           coords.last!.longitude != coords.first!.longitude {
            let endPin = MKPointAnnotation()
            endPin.coordinate = coords.last!
            endPin.title = "Finish"
            mapView.addAnnotation(endPin)
        }

        // Checkpoints
        for i in 1..<coords.count - 1 {
            let cp = MKPointAnnotation()
            cp.coordinate = coords[i]
            cp.title = "CP\(i)"
            mapView.addAnnotation(cp)
        }

        // Fit map to route with padding
        let fittingRect = polyline.boundingMapRect
        if !fittingRect.isNull && !fittingRect.isEmpty {
            mapView.setVisibleMapRect(
                fittingRect,
                edgePadding: UIEdgeInsets(top: 36, left: 36, bottom: 36, right: 36),
                animated: false
            )
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.systemBlue
            renderer.lineWidth = 4
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let point = annotation as? MKPointAnnotation else { return nil }

            // Use separate reuse buckets so colours don't bleed across dequeued views
            let isCheckpoint = point.title?.hasPrefix("CP") == true
            let reuseID = point.title == "Start" ? "overviewPin_start"
                        : point.title == "Finish" ? "overviewPin_finish"
                        : "overviewPin_checkpoint"

            let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseID) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
            view.annotation = annotation
            view.canShowCallout = false
            view.displayPriority = .required

            switch point.title {
            case "Start":
                view.markerTintColor = .systemGreen
                view.glyphImage = UIImage(systemName: "flag.fill")
                view.glyphText = nil
            case "Finish":
                view.markerTintColor = .systemRed
                view.glyphImage = UIImage(systemName: "flag.checkered")
                view.glyphText = nil
            default:
                // Extract checkpoint number from "CP1", "CP2", etc.
                if isCheckpoint, let numStr = point.title?.dropFirst(2), let num = Int(numStr) {
                    view.markerTintColor = .systemBlue
                    view.glyphText = "\(num)"
                    view.glyphImage = nil
                } else {
                    view.markerTintColor = .systemBlue
                    view.glyphImage = UIImage(systemName: "mappin")
                    view.glyphText = nil
                }
            }
            return view
        }
    }
}
