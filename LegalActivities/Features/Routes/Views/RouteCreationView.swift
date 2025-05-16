//
//  RouteCreationView.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/12/25.
//
import SwiftUI
import MapKit

struct RouteCreationView: View {
    @StateObject var vm = RouteCreationViewModel()
    @State private var selectedPointType: LocationPin.PointType = .start
    @State private var mapView = MKMapView()
    @State private var showingSaveSheet = false
    @State private var dragInProgress = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Map View with drag handling
            MapViewBridge(
                            mapView: $mapView,
                            annotations: vm.annotations,
                            routeSegments: vm.routeSegments,
                            vm: vm,
                            onMapTap: handleMapTap,
                            // <<< Use the updated callback name
                            onAnnotationDragStateChanged: handleAnnotationDragStateChanged
                        )
                        .edgesIgnoringSafeArea(.all)
                        .onAppear(perform: setupMap)
            
            // Control Panel
            VStack(spacing: 16) {
                headerControls
                
                // Horizontal Point Type Selector
                HStack(spacing: 20) {
                    ControlButton(
                        icon: "flag.fill",
                        label: "Start",
                        color: .green,
                        isSelected: selectedPointType == .start
                    ) {
                        selectedPointType = .start
                    }
                    
                    ControlButton(
                        icon: "mappin.circle.fill",
                        label: "Checkpoint",
                        color: .blue,
                        isSelected: selectedPointType == .checkpoint
                    ) {
                        selectedPointType = .checkpoint
                    }
                    
                    ControlButton(
                        icon: "flag.checkered",
                        label: "End",
                        color: .red,
                        isSelected: selectedPointType == .end
                    ) {
                        selectedPointType = .end
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                
                // Contextual Controls
                HStack {
                    if vm.selectedAnnotation != nil {
                        Button(action: vm.removeSelectedAnnotation) {
                            Image(systemName: "trash")
                                .padding(12)
                                .background(.red)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: { showingSaveSheet = true }) {
                        Image(systemName: "square.and.arrow.down")
                            .padding(12)
                            .background(vm.canSaveRoute ? .blue : .gray)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .disabled(!vm.canSaveRoute)
                    
                    Button(action: { vm.zoomToFitRouteSegments(mapView: mapView) }) {
                        Image(systemName: "location.magnifyingglass")
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .sheet(isPresented: $showingSaveSheet) {
            SaveRouteView(vm: vm, isPresented: $showingSaveSheet)
        }
        .overlay(
            Text(dragInProgress ? "Drag to rearrange checkpoints" : "Long press checkpoints to move")
                .font(.caption)
                .padding(8)
                .background(.regularMaterial)
                .cornerRadius(8)
                .opacity(vm.checkpoints.isEmpty ? 0 : 1)
                .animation(.easeInOut, value: vm.checkpoints.isEmpty),
            alignment: .top
        )
    }
    
    private func handleAnnotationDragStateChanged(_ annotation: LocationPin, newCoordinate: CLLocationCoordinate2D, dragState: AnnotationDragState) {
        switch dragState {
        case .starting:
            dragInProgress = true
            // vm.selectAnnotation(annotation) is now called by the Coordinator's didChangeDragState
            print("View: Drag Starting for \(annotation.type)")
        case .dragging:
            dragInProgress = true
            // For live route updates (can be performance intensive if vm.updateAnnotationPosition causes full recalc):
            // vm.updateAnnotationPosition(annotation, newCoordinate: newCoordinate)
            print("View: Dragging \(annotation.type)")
            break
        case .ending:
            dragInProgress = false
            vm.updateAnnotationPosition(annotation, newCoordinate: newCoordinate)
            print("View: Drag Ended for \(annotation.type)")
        case .canceling:
            dragInProgress = false
            // MapKit might have already reverted the annotation's coordinate if it supports revert on cancel.
            // Or, it might leave it at the last dragged position.
            // We update our model to whatever coordinate the annotation has at cancellation.
            vm.updateAnnotationPosition(annotation, newCoordinate: newCoordinate)
            print("View: Drag Canceled for \(annotation.type)")
        case .none: // This state is after .ending or .canceling
            if dragInProgress { // If we were indeed tracking a drag
                dragInProgress = false
                // The position should have been updated by .ending or .canceling handler
                // but if MKMapView calls .none after .ending, ensure model consistency.
                // vm.updateAnnotationPosition(annotation, newCoordinate: newCoordinate)
                print("View: Drag transitioned to None for \(annotation.type)")
            }
        }
    }
    
    private func setupMap() {
        mapView.showsUserLocation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            vm.centerMapOnUser(mapView: mapView)
        }
    }
    
    private func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        vm.addAnnotation(at: coordinate, type: selectedPointType)
    }
    
    private func handleAnnotationDrag(_ annotation: LocationPin, newCoordinate: CLLocationCoordinate2D) {
        if annotation.type == .checkpoint {
            dragInProgress = true
            vm.updateAnnotationPosition(annotation, newCoordinate: newCoordinate)
        }
    }
    
    private var headerControls: some View {
            HStack {
                if vm.selectedAnnotation != nil && vm.selectedAnnotation?.type == .checkpoint {
                    Button(action: vm.removeSelectedAnnotation) {
                        Label("Remove", systemImage: "trash")
                            .controlStyle(.destructive)
                    }
                }
                
                Spacer()
                
                Button(action: { showingSaveSheet = true }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .controlStyle(.primary)
                }
                .disabled(!vm.canSaveRoute)
            }
            .padding()
            .background(.ultraThinMaterial)
        }

}


// MARK: - Style Modifiers
struct ControlButtonStyle: ButtonStyle {
    let color: Color
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(12)
            .background(isSelected ? color.opacity(0.2) : Color.clear)
            .foregroundColor(isSelected ? color : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color : .clear, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

extension View {
    func controlStyle(_ style: ControlStyle) -> some View {
        self.modifier(ControlStyleModifier(style: style))
    }
}

enum ControlStyle {
    case primary, destructive
}

struct ControlStyleModifier: ViewModifier {
    let style: ControlStyle
    
    func body(content: Content) -> some View {
        switch style {
        case .primary:
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())
        case .destructive:
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red)
                .foregroundColor(.white)
                .clipShape(Capsule())
        }
    }
}

enum AnnotationDragState {
    case starting, dragging, ending, canceling, none
}


// MARK: - Helper Structs & Extensions (Ensure these are defined)
struct MapViewBridge: UIViewRepresentable {
    @Binding var mapView: MKMapView
    var annotations: [LocationPin] // Your LocationPin model
    var routeSegments: [MKPolyline]
    @ObservedObject var vm: RouteCreationViewModel // Your ViewModel
    var onMapTap: (CLLocationCoordinate2D) -> Void
    var onAnnotationDragStateChanged: (LocationPin, CLLocationCoordinate2D, AnnotationDragState) -> Void

    func makeUIView(context: Context) -> MKMapView {
        mapView.delegate = context.coordinator
        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        mapView.addGestureRecognizer(tapRecognizer)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Remove old annotations (excluding user location)
        let oldAnnotationsOnMap = uiView.annotations.filter { !($0 is MKUserLocation) }
        uiView.removeAnnotations(oldAnnotationsOnMap)
        // Add new annotations from the ViewModel
        uiView.addAnnotations(annotations)

        // Update overlays
        uiView.removeOverlays(uiView.overlays)
        uiView.addOverlays(routeSegments)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, vm: vm)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewBridge
        var vm: RouteCreationViewModel
        let segmentColors: [UIColor] = [ .systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemRed, .systemTeal, .systemIndigo, .systemYellow ]

        init(_ parent: MapViewBridge, vm: RouteCreationViewModel) {
            self.parent = parent
            self.vm = vm
            super.init()
        }

        @objc func handleMapTap(_ gestureRecognizer: UITapGestureRecognizer) {
            guard gestureRecognizer.state == .ended else { return }
            let mapView = gestureRecognizer.view as! MKMapView
            let touchPoint = gestureRecognizer.location(in: mapView)
            
            var tappedOnAnnotationView = false
            for annotation in mapView.annotations {
                if let view = mapView.view(for: annotation) {
                    // Check if the tap is within the bounds of an existing annotation view
                    let touchPointInView = gestureRecognizer.location(in: view)
                    if view.bounds.contains(touchPointInView) {
                        tappedOnAnnotationView = true
                        mapView.selectAnnotation(annotation, animated: true) // Explicitly select
                        break
                    }
                }
            }
            
            if !tappedOnAnnotationView {
                let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
                parent.onMapTap(coordinate)
            }
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let locationPin = view.annotation as? LocationPin else {
                if !(view.annotation is MKUserLocation) { // Don't deselect for user dot taps
                    vm.selectAnnotation(nil)
                }
                return
            }
            // Defer selection to drag handler if a drag is likely starting
            if view.isDraggable && (view.dragState == .starting || view.dragState == .dragging) {
                return
            }
            vm.selectAnnotation(locationPin)
        }
        
        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            if let deselectedPin = view.annotation as? LocationPin, vm.selectedAnnotation?.id == deselectedPin.id {
                vm.selectAnnotation(nil)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            guard let locationPin = annotation as? LocationPin else { return nil }
            
            let reuseIdentifier = "customAnnotation_\(locationPin.type.hashValue)_\(locationPin.id)"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)

            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
            } else {
                annotationView?.annotation = annotation
            }

            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.isDraggable = true // Make pins draggable
                
                markerView.canShowCallout = (locationPin.type == .checkpoint)
                markerView.markerTintColor = UIColor(locationPin.type.markerColor) // Ensure UIColor extension for Color exists
                markerView.glyphImage = UIImage(systemName: locationPin.type.icon)

                if locationPin.type == .checkpoint, let number = vm.getCheckpointNumber(for: locationPin) {
                    markerView.glyphText = "\(number)"
                } else {
                    markerView.glyphText = nil
                }

                if vm.selectedAnnotation?.id == locationPin.id {
                    markerView.markerTintColor = UIColor.yellow
                    markerView.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                    markerView.zPriority = .max
                } else {
                    markerView.markerTintColor = UIColor(locationPin.type.markerColor)
                    markerView.transform = .identity
                    markerView.zPriority = .defaultUnselected
                }
            }
            return annotationView
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
            guard let locationPinAnnotation = view.annotation as? LocationPin else { return }

            let currentCoordinate = view.annotation!.coordinate
            var swiftUIDragState: AnnotationDragState = .none

            switch newState {
            case .starting:
                swiftUIDragState = .starting
                vm.selectAnnotation(locationPinAnnotation) // Select when drag starts
                parent.onAnnotationDragStateChanged(locationPinAnnotation, currentCoordinate, swiftUIDragState)
                return
            case .dragging:
                swiftUIDragState = .dragging
                parent.onAnnotationDragStateChanged(locationPinAnnotation, currentCoordinate, swiftUIDragState)
                return
            case .ending:
                swiftUIDragState = .ending
            case .canceling:
                swiftUIDragState = .canceling
            case .none:
                if oldState == .dragging || oldState == .ending || oldState == .canceling {
                    swiftUIDragState = .none
                } else { return }
            @unknown default:
                return
            }
            parent.onAnnotationDragStateChanged(locationPinAnnotation, currentCoordinate, swiftUIDragState)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                if let index = vm.routeSegments.firstIndex(where: { $0 === polyline }) {
                    renderer.strokeColor = segmentColors[index % segmentColors.count]
                } else {
                    renderer.strokeColor = .darkGray
                }
                renderer.lineWidth = 5; renderer.lineCap = .round; renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// Needs UIColor extension for Color conversion
extension UIColor {
    convenience init(_ color: Color) {
        // Simplified version - assumes RGB color space from SwiftUI Color
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if let cgColor = color.cgColor, let components = cgColor.components {
            let numberOfComponents = cgColor.numberOfComponents
            if numberOfComponents >= 3 { // RGB or RGBA
                r = components[0]; g = components[1]; b = components[2]
                a = components.count >= 4 ? components[3] : 1.0
            } else if numberOfComponents == 2 { // Grayscale
                r = components[0]; g = components[0]; b = components[0]; a = components[1]
            }
        }
        // Add a fallback or handle other color spaces if necessary
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}


// MARK: - Preview
struct RouteCreationView_Previews: PreviewProvider {
    static var previews: some View {
        // Wrap in NavigationView for preview context if needed
        NavigationView {
            RouteCreationView()
        }
    }
}
