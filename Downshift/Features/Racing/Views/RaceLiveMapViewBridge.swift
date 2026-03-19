//
//  RaceLiveMapViewBridge.swift
//  Downshift
//

import SwiftUI
import MapKit

// MARK: - Coloured polyline overlay

/// An MKPolyline subclass that carries a UIColor so the renderer can colour it correctly.
final class ColouredPolyline: MKPolyline {
    var colour: UIColor = .systemBlue
    var lineWidth: CGFloat = 5
}

// MARK: - Pacenote annotation

/// Annotation placed at the start of each detected rally curve.
final class PacenoteAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    /// Rally rank 1–8 (1=hairpin, 8=six).  Actually stored as the engine rank.
    let rank: Int
    /// true = right turn
    let isRight: Bool
    let modifierText: String?

    init(coordinate: CLLocationCoordinate2D,
         rank: Int, isRight: Bool, modifierText: String?) {
        self.coordinate   = coordinate
        self.rank         = rank
        self.isRight      = isRight
        self.modifierText = modifierText
    }

    // Colour matching the reference app's severity palette
    var badgeColour: UIColor {
        switch rank {
        case 8:  return UIColor(red: 0.9, green: 0.2, blue: 0.8, alpha: 1) // hairpin → magenta
        case 7:  return UIColor(red: 1.0, green: 0.3, blue: 0.1, alpha: 1) // square  → red-orange
        case 6:  return UIColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 1) // one    → deep orange
        case 5:  return UIColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1) // two    → orange
        case 4:  return UIColor(red: 1.0, green: 0.70, blue: 0.0, alpha: 1) // three  → amber
        case 3:  return UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1) // four   → yellow-orange
        case 2:  return UIColor(red: 0.9, green: 0.95, blue: 0.0, alpha: 1) // five   → yellow-green
        default: return UIColor(red: 0.6, green: 0.90, blue: 0.1, alpha: 1) // six    → lime
        }
    }

    /// Arrow icon name for the direction
    var arrowSystemImage: String {
        isRight ? "arrow.turn.up.right" : "arrow.turn.up.left"
    }
}

// MARK: - RaceLiveMapViewBridge

struct RaceLiveMapViewBridge: UIViewRepresentable {
    @Binding var mapView: MKMapView
    @Binding var region: MKCoordinateRegion
    let routeToDisplay: SavedRoute?
    let nextTargetCoordinate: CLLocationCoordinate2D?
    let currentRaceState: RaceState
    /// Road-snapped polylines from MKDirections (used for geometry; we re-colour them).
    var roadPolylines: [MKPolyline] = []
    /// Dense coords matching roadPolylines (joined).
    var roadCoords: [CLLocationCoordinate2D] = []
    /// Detected rally curves used for colouring + badges.
    var rallyCurves: [RallyCurve] = []
    /// Total route distance in metres (for progress mapping).
    var routeTotalDistance: Double = 0
    /// When false, the coloured segments and pacenote badges are hidden.
    var rallyMode: Bool = false

    // MARK: UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        mapView.delegate              = context.coordinator
        mapView.showsUserLocation     = true
        mapView.mapType               = .mutedStandard
        mapView.pointOfInterestFilter = .excludingAll
        // Start with follow+heading so the map centres on the user before
        // the first location update fires and we switch to manual camera control.
        mapView.userTrackingMode      = .followWithHeading
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Region update only when user isn't tracking
        if uiView.userTrackingMode == .none {
            let changed = abs(uiView.region.center.latitude  - region.center.latitude)  > 0.0001 ||
                          abs(uiView.region.center.longitude - region.center.longitude) > 0.0001 ||
                          abs(uiView.region.span.latitudeDelta  - region.span.latitudeDelta)  > 0.0001 ||
                          abs(uiView.region.span.longitudeDelta - region.span.longitudeDelta) > 0.0001
            if changed { uiView.setRegion(region, animated: true) }
        }

        // Clear previous overlays + non-user annotations
        uiView.removeAnnotations(uiView.annotations.filter { !($0 is MKUserLocation) })
        uiView.removeOverlays(uiView.overlays)

        guard let route = routeToDisplay else { return }

        let baseCoords = roadCoords.isEmpty ? route.clCoordinates : roadCoords

        if rallyMode {
            // ── 1. Route polyline (colour-coded by severity) ──────────────────
            addColouredPolylines(to: uiView, coords: baseCoords)

            // ── 2. Pacenote badges ────────────────────────────────────────────
            addPacenoteAnnotations(to: uiView, coords: baseCoords)
        } else {
            // ── 1. Plain blue polyline ────────────────────────────────────────
            if baseCoords.count > 1 {
                let poly = MKPolyline(coordinates: baseCoords, count: baseCoords.count)
                uiView.addOverlay(poly, level: .aboveRoads)
            }
        }

        // ── 3. Start / checkpoint / finish pins ───────────────────────────────
        addRoutePins(to: uiView, route: route)

        // ── 4. Initial fit ────────────────────────────────────────────────────
        if context.coordinator.isInitialLoad && route.clCoordinates.count > 1 {
            if uiView.userTrackingMode == .none {
                let poly = MKPolyline(coordinates: route.clCoordinates,
                                      count: route.clCoordinates.count)
                let rect = poly.boundingMapRect
                if !rect.isNull {
                    uiView.setVisibleMapRect(rect,
                                             edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40),
                                             animated: true)
                }
            }
            context.coordinator.isInitialLoad = false
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coloured polyline builder

    private func addColouredPolylines(to mapView: MKMapView,
                                       coords: [CLLocationCoordinate2D]) {
        guard coords.count >= 2 else { return }

        if rallyCurves.isEmpty {
            // No curves detected yet — plain blue line
            let plain = MKPolyline(coordinates: coords, count: coords.count)
            mapView.addOverlay(plain, level: .aboveRoads)
            return
        }

        // Build a cumulative-distance index for the coords array
        var cumDists = [Double](repeating: 0, count: coords.count)
        for i in 1..<coords.count {
            let a = CLLocation(latitude: coords[i-1].latitude, longitude: coords[i-1].longitude)
            let b = CLLocation(latitude: coords[i].latitude,   longitude: coords[i].longitude)
            cumDists[i] = cumDists[i-1] + a.distance(from: b)
        }
        let totalDist = cumDists.last ?? 0
        guard totalDist > 0 else { return }

        // Map a progress value (metres) → index in coords
        func coordIndex(for progress: Double) -> Int {
            let clamped = max(0, min(totalDist, progress))
            // Binary search
            var lo = 0, hi = coords.count - 1
            while lo < hi {
                let mid = (lo + hi + 1) / 2
                if cumDists[mid] <= clamped { lo = mid } else { hi = mid - 1 }
            }
            return lo
        }

        // Build segments: straight (grey) + coloured curve segments
        // We paint the whole route grey first, then overlay coloured segments on top.

        // Grey base
        let basePoly = ColouredPolyline(coordinates: coords, count: coords.count)
        basePoly.colour    = UIColor.white.withAlphaComponent(0.30)
        basePoly.lineWidth = 4
        mapView.addOverlay(basePoly, level: .aboveRoads)

        // Coloured curve overlays
        for curve in rallyCurves {
            let startIdx = coordIndex(for: curve.start)
            let endIdx   = min(coordIndex(for: curve.end), coords.count - 1)
            guard endIdx > startIdx else { continue }

            let segCoords = Array(coords[startIdx...endIdx])
            let poly      = ColouredPolyline(coordinates: segCoords, count: segCoords.count)
            poly.colour    = uiColour(for: curve.rank)
            poly.lineWidth = 6
            mapView.addOverlay(poly, level: .aboveRoads)
        }
    }

    // MARK: - Pacenote annotation builder

    private func addPacenoteAnnotations(to mapView: MKMapView,
                                         coords: [CLLocationCoordinate2D]) {
        guard !rallyCurves.isEmpty, !coords.isEmpty else { return }

        var cumDists = [Double](repeating: 0, count: coords.count)
        for i in 1..<coords.count {
            let a = CLLocation(latitude: coords[i-1].latitude, longitude: coords[i-1].longitude)
            let b = CLLocation(latitude: coords[i].latitude,   longitude: coords[i].longitude)
            cumDists[i] = cumDists[i-1] + a.distance(from: b)
        }
        let totalDist = cumDists.last ?? 0
        guard totalDist > 0 else { return }

        func coordIndex(for progress: Double) -> Int {
            let clamped = max(0, min(totalDist, progress))
            var lo = 0, hi = coords.count - 1
            while lo < hi {
                let mid = (lo + hi + 1) / 2
                if cumDists[mid] <= clamped { lo = mid } else { hi = mid - 1 }
            }
            return lo
        }

        for curve in rallyCurves {
            let idx   = coordIndex(for: curve.start)
            let coord = coords[min(idx, coords.count - 1)]

            let mod: String?
            if curve.isExtraLong { mod = "XL" }
            else if curve.isLong  { mod = "L"  }
            else if curve.isShort { mod = "S"  }
            else                  { mod = nil  }

            let ann = PacenoteAnnotation(
                coordinate:   coord,
                rank:         curve.rank,
                isRight:      curve.orientation,   // orientation: true = right
                modifierText: mod
            )
            mapView.addAnnotation(ann)
        }
    }

    // MARK: - Route pin builder

    private func addRoutePins(to mapView: MKMapView, route: SavedRoute) {
        var pins: [LocationPin] = []

        if let start = route.startCoordinate {
            pins.append(LocationPin(coordinate: start, type: .start))
        }
        for i in 1..<(route.clCoordinates.count - 1) {
            let cp = LocationPin(coordinate: route.clCoordinates[i], type: .checkpoint)
            let isNext = (route.clCoordinates[i].latitude  == nextTargetCoordinate?.latitude &&
                          route.clCoordinates[i].longitude == nextTargetCoordinate?.longitude)
            cp.isNext = isNext
            pins.append(cp)
        }
        if let end = route.endCoordinate,
           (route.clCoordinates.count == 1 ||
            end.latitude  != route.startCoordinate?.latitude ||
            end.longitude != route.startCoordinate?.longitude) {
            pins.append(LocationPin(coordinate: end, type: .end))
        }
        mapView.addAnnotations(pins)
    }

    // MARK: - Severity → UIColor

    private func uiColour(for rank: Int) -> UIColor {
        switch rank {
        case 8:  return UIColor(red: 0.9, green: 0.2, blue: 0.8, alpha: 1) // hairpin → magenta
        case 7:  return UIColor(red: 1.0, green: 0.3, blue: 0.1, alpha: 1) // square  → red-orange
        case 6:  return UIColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 1)
        case 5:  return UIColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1)
        case 4:  return UIColor(red: 1.0, green: 0.70, blue: 0.0, alpha: 1)
        case 3:  return UIColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1)
        case 2:  return UIColor(red: 0.9, green: 0.95, blue: 0.0, alpha: 1)
        default: return UIColor(red: 0.6, green: 0.90, blue: 0.1, alpha: 1) // six → lime
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RaceLiveMapViewBridge
        var isInitialLoad = true

        init(_ parent: RaceLiveMapViewBridge) { self.parent = parent }

        // MARK: Overlay renderer

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let coloured = overlay as? ColouredPolyline {
                let r = MKPolylineRenderer(polyline: coloured)
                r.strokeColor = coloured.colour
                r.lineWidth   = coloured.lineWidth
                r.lineCap     = .round
                r.lineJoin    = .round
                return r
            }
            if let polyline = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: polyline)
                r.strokeColor = UIColor.systemBlue.withAlphaComponent(0.85)
                r.lineWidth   = 5
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: Annotation view

        func mapView(_ mapView: MKMapView,
                     viewFor annotation: MKAnnotation) -> MKAnnotationView? {

            if annotation is MKUserLocation { return nil }

            // ── Pacenote badge ───────────────────────────────────────────────
            if let pacenote = annotation as? PacenoteAnnotation {
                let reuseId = "pacenote"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
                          ?? MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                view.annotation       = annotation
                view.canShowCallout   = false
                view.image            = makeBadgeImage(for: pacenote)
                view.centerOffset     = CGPoint(x: 0, y: -14)
                view.zPriority        = .max
                return view
            }

            // ── Route pins ───────────────────────────────────────────────────
            guard let locationPin = annotation as? LocationPin else { return nil }
            let reuseId = "racePin_\(locationPin.type.hashValue)_\(locationPin.id)"
            let pinView = (mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKMarkerAnnotationView)
                       ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseId)

            pinView.annotation      = annotation
            pinView.canShowCallout  = false
            pinView.markerTintColor = UIColor(locationPin.type.markerColor)
            pinView.glyphImage      = UIImage(systemName: locationPin.type.icon)

            if locationPin.isNext ?? false {
                pinView.markerTintColor = .orange
                pinView.transform       = CGAffineTransform(scaleX: 1.3, y: 1.3)
                pinView.zPriority       = .max
            } else {
                pinView.transform = .identity
                pinView.zPriority = .defaultUnselected
            }
            if locationPin.type == .start && parent.currentRaceState == .inProgress {
                pinView.alpha = 0.4
            } else {
                pinView.alpha = 1.0
            }
            return pinView
        }

        func mapView(_ mapView: MKMapView,
                     didChange mode: MKUserTrackingMode, animated: Bool) {
            // no-op; recenter button in parent handles this
        }

        // MARK: Location-driven camera (pitched, forward-facing)

        /// Updates the camera every time MapKit reports a new user position.
        /// Uses the location's `course` as the heading so the map always faces
        /// the direction of travel, with a forward pitch so the road ahead is visible.
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard parent.currentRaceState == .inProgress else { return }
            guard let location = userLocation.location else { return }

            // Only act when we have a reliable course (≥0 means valid)
            let course = location.course
            guard course >= 0 else { return }

            let speed   = max(location.speed, 0)         // m/s

            // Eye distance: closer at low speed (e.g. corners), further at high speed.
            // Range: 120 m (stationary) → 400 m (≈ 140 km/h).
            let eyeDistance = min(120 + speed * 10, 400)

            // Pitch: steeper at low speed for better overview; flatter at high speed.
            // Range: 55° (fast) → 70° (slow/stopped).
            let pitch: Double = min(55 + (1 - min(speed / 28, 1)) * 15, 70)

            let camera = MKMapCamera(
                lookingAtCenter: location.coordinate,
                fromDistance:    eyeDistance,
                pitch:           pitch,
                heading:         course
            )

            // Disable MapKit's built-in tracking so our camera takes full control.
            if mapView.userTrackingMode != .none {
                mapView.setUserTrackingMode(.none, animated: false)
            }

            mapView.setCamera(camera, animated: true)
        }

        // MARK: Badge image renderer

        private func makeBadgeImage(for pacenote: PacenoteAnnotation) -> UIImage {
            let size   = CGSize(width: 36, height: 36)
            let corner: CGFloat = 6
            let bg     = pacenote.badgeColour

            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { ctx in
                let rect = CGRect(origin: .zero, size: size)

                // Rounded square background
                let path = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1),
                                        cornerRadius: corner)
                bg.setFill()
                path.fill()

                // Dark border
                UIColor.black.withAlphaComponent(0.5).setStroke()
                path.lineWidth = 1.5
                path.stroke()

                // Arrow icon
                let arrowName = pacenote.isRight ? "arrow.turn.up.right" : "arrow.turn.up.left"
                let config    = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
                if let arrow  = UIImage(systemName: arrowName, withConfiguration: config) {
                    let tinted   = arrow.withTintColor(.black, renderingMode: .alwaysOriginal)
                    let iconSize = CGSize(width: 20, height: 20)
                    let iconRect = CGRect(
                        x: (size.width  - iconSize.width)  / 2,
                        y: (size.height - iconSize.height) / 2 - (pacenote.modifierText != nil ? 3 : 0),
                        width:  iconSize.width,
                        height: iconSize.height
                    )
                    tinted.draw(in: iconRect)
                }

                // Modifier label (S / L / XL)
                if let mod = pacenote.modifierText {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font:            UIFont.systemFont(ofSize: 7, weight: .black),
                        .foregroundColor: UIColor.black.withAlphaComponent(0.8)
                    ]
                    let str  = NSAttributedString(string: mod, attributes: attrs)
                    let strSize = str.size()
                    str.draw(at: CGPoint(
                        x: (size.width - strSize.width) / 2,
                        y: size.height - strSize.height - 3
                    ))
                }
            }
        }
    }
}
