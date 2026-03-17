//
//  RouteCreationView.swift
//  LegalActivities
//

import SwiftUI
import MapKit

struct RouteCreationView: View {
    @StateObject var vm = RouteCreationViewModel()
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPointType: LocationPin.PointType = .start
    @State private var mapView = MKMapView()
    @State private var showingSaveSheet = false
    @State private var dragInProgress = false
    @State private var showCheckpointList = false
    @State private var isCalculatingRoute = false
    @State private var savedRouteName: String? = nil  // set on success → triggers success overlay

    var body: some View {
        ZStack {
            // MARK: - Full-screen map
            MapViewBridge(
                mapView: $mapView,
                annotations: vm.annotations,
                routeSegments: vm.routeSegments,
                vm: vm,
                onMapTap: handleMapTap,
                onAnnotationDragStateChanged: handleAnnotationDragStateChanged
            )
            .ignoresSafeArea()
            .onAppear(perform: setupMap)

            // MARK: - Top bar
            VStack {
                topBar
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            // MARK: - Bottom panel
            VStack {
                Spacer()
                bottomPanel
            }
            .ignoresSafeArea(edges: .bottom)

            // MARK: - Route calculating indicator
            if isCalculatingRoute {
                VStack {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                        Text("Calculating route…")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 120)
                    Spacer()
                }
            }

            // MARK: - Route saved success overlay
            if let name = savedRouteName {
                RouteCreatedOverlay(routeName: name) {
                    appState.loadRoutes()
                    appState.selectedTab = 0
                    dismiss()
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showingSaveSheet) {
            SaveRouteView(vm: vm, isPresented: $showingSaveSheet) { name in
                withAnimation(.easeInOut(duration: 0.35)) {
                    savedRouteName = name
                }
            }
        }
        .sheet(isPresented: $showCheckpointList) {
            checkpointListSheet
        }
        // Observe when segments finish calculating
        .onChange(of: vm.routeSegments) {
            withAnimation { isCalculatingRoute = false }
        }
        .onChange(of: vm.annotations) {
            if vm.annotations.count >= 2 {
                withAnimation { isCalculatingRoute = true }
            }
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack(spacing: 12) {
            // Back button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(.regularMaterial, in: Circle())
            }

            Spacer()

            // Route stats pill
            if !vm.annotations.isEmpty {
                routeStatsPill
                    .transition(.scale.combined(with: .opacity))
            }

            Spacer()

            // Zoom-to-fit button
            Button {
                vm.zoomToFitRouteSegments(mapView: mapView)
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(.regularMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
        .animation(.spring(response: 0.3), value: vm.annotations.isEmpty)
    }

    private var routeStatsPill: some View {
        HStack(spacing: 10) {
            Label("\(vm.annotations.count)", systemImage: "mappin")
                .font(.caption)
                .fontWeight(.semibold)

            if vm.routeSegments.count > 0 {
                Divider().frame(height: 12)
                Label("\(vm.routeSegments.count) seg", systemImage: "road.lanes")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule())
    }

    // MARK: - Bottom Panel
    private var bottomPanel: some View {
        VStack(spacing: 0) {
            // Selected pin action bar (slides in when a pin is selected)
            if let selected = vm.selectedAnnotation {
                selectedPinBar(for: selected)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Divider line
            Divider().opacity(0.3)

            // Pin type selector
            pinTypeSelector

            // Action row
            actionRow
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -4)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.selectedAnnotation?.id)
    }

    // MARK: - Selected Pin Bar
    private func selectedPinBar(for pin: LocationPin) -> some View {
        HStack(spacing: 16) {
            // Pin type icon
            Image(systemName: pin.type.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(pinTypeColor(pin.type))
                .frame(width: 40, height: 40)
                .background(pinTypeColor(pin.type).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(pin.type == .start ? "Start Point" : pin.type == .end ? "End Point" : "Checkpoint \(vm.getCheckpointNumber(for: pin) ?? 0)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Selected — tap map to deselect")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                withAnimation { vm.removeSelectedAnnotation() }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.red)
                    .frame(width: 36, height: 36)
                    .background(Color.red.opacity(0.1), in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Pin Type Selector
    private var pinTypeSelector: some View {
        HStack(spacing: 8) {
            PinTypeButton(
                icon: "flag.fill",
                label: "Start",
                color: .green,
                isSelected: selectedPointType == .start,
                hasPin: vm.annotations.contains { $0.type == .start }
            ) {
                selectedPointType = .start
            }

            PinTypeButton(
                icon: "mappin",
                label: "Checkpoint",
                color: .blue,
                isSelected: selectedPointType == .checkpoint,
                hasPin: !vm.checkpoints.isEmpty
            ) {
                selectedPointType = .checkpoint
            }

            PinTypeButton(
                icon: "flag.checkered",
                label: "Finish",
                color: .red,
                isSelected: selectedPointType == .end,
                hasPin: vm.annotations.contains { $0.type == .end }
            ) {
                selectedPointType = .end
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Action Row
    private var actionRow: some View {
        HStack(spacing: 12) {
            // Checkpoint list button (only visible when checkpoints exist)
            if !vm.checkpoints.isEmpty {
                Button {
                    showCheckpointList = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.number")
                            .font(.system(size: 14, weight: .medium))
                        Text("\(vm.checkpoints.count)")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .transition(.scale.combined(with: .opacity))
            }

            // User location button
            Button {
                vm.centerMapOnUser(mapView: mapView)
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(10)
                    .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }

            Spacer()

            // Save button
            Button {
                showingSaveSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                    Text("Save Route")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(
                    vm.canSaveRoute
                        ? Color.blue
                        : Color.secondary.opacity(0.3),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .disabled(!vm.canSaveRoute)
            .animation(.easeInOut(duration: 0.2), value: vm.canSaveRoute)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .animation(.spring(response: 0.3), value: vm.checkpoints.isEmpty)
    }

    // MARK: - Checkpoint List Sheet
    private var checkpointListSheet: some View {
        NavigationStack {
            List {
                if vm.checkpoints.isEmpty {
                    ContentUnavailableView("No Checkpoints", systemImage: "mappin.slash", description: Text("Tap the map with 'Checkpoint' selected to add one."))
                } else {
                    ForEach(vm.checkpoints, id: \.id) { cp in
                        Button {
                            vm.selectAnnotation(cp)
                            let region = MKCoordinateRegion(
                                center: cp.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                            )
                            mapView.setRegion(region, animated: true)
                            showCheckpointList = false
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Text("\(vm.getCheckpointNumber(for: cp) ?? 0)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.blue)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Checkpoint \(vm.getCheckpointNumber(for: cp) ?? 0)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    Text(String(format: "%.5f, %.5f", cp.coordinate.latitude, cp.coordinate.longitude))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "scope")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { vm.deleteCheckpointsFromList(atOffsets: $0) }
                    .onMove { vm.moveCheckpointInList(from: $0, to: $1) }
                }
            }
            .navigationTitle("Checkpoints")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showCheckpointList = false }
                }
                if !vm.checkpoints.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helpers
    private func pinTypeColor(_ type: LocationPin.PointType) -> Color {
        switch type {
        case .start: return .green
        case .checkpoint: return .blue
        case .end: return .red
        }
    }

    private func handleMapTap(_ coordinate: CLLocationCoordinate2D) {
        vm.addAnnotation(at: coordinate, type: selectedPointType)
    }

    private func handleAnnotationDragStateChanged(_ annotation: LocationPin, newCoordinate: CLLocationCoordinate2D, dragState: AnnotationDragState) {
        switch dragState {
        case .starting:
            dragInProgress = true
        case .dragging:
            dragInProgress = true
        case .ending:
            dragInProgress = false
            vm.updateAnnotationPosition(annotation, newCoordinate: newCoordinate)
        case .canceling:
            dragInProgress = false
            vm.updateAnnotationPosition(annotation, newCoordinate: newCoordinate)
        case .none:
            if dragInProgress { dragInProgress = false }
        }
    }

    private func setupMap() {
        mapView.showsUserLocation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            vm.centerMapOnUser(mapView: mapView)
        }
    }
}

// MARK: - Pin Type Button
private struct PinTypeButton: View {
    let icon: String
    let label: String
    let color: Color
    let isSelected: Bool
    let hasPin: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? .white : color)
                        .frame(width: 48, height: 48)
                        .background(
                            isSelected ? color : color.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(isSelected ? color : Color.clear, lineWidth: 2)
                        )

                    // Placed dot indicator
                    if hasPin {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().fill(color).padding(2))
                            .offset(x: 4, y: -4)
                    }
                }

                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? color : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Style Modifiers (kept for compatibility)
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

// MARK: - MapViewBridge (unchanged core logic, kept here)
struct MapViewBridge: UIViewRepresentable {
    @Binding var mapView: MKMapView
    var annotations: [LocationPin]
    var routeSegments: [MKPolyline]
    @ObservedObject var vm: RouteCreationViewModel
    var onMapTap: (CLLocationCoordinate2D) -> Void
    var onAnnotationDragStateChanged: (LocationPin, CLLocationCoordinate2D, AnnotationDragState) -> Void

    func makeUIView(context: Context) -> MKMapView {
        mapView.delegate = context.coordinator
        let tapRecognizer = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        mapView.addGestureRecognizer(tapRecognizer)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Diff annotations to avoid removing pins that are actively being dragged
        let existing = uiView.annotations.compactMap { $0 as? LocationPin }
        let existingIDs = Set(existing.map { $0.id })
        let newIDs = Set(annotations.map { $0.id })

        let toRemove = existing.filter { !newIDs.contains($0.id) }
        let toAdd = annotations.filter { !existingIDs.contains($0.id) }

        uiView.removeAnnotations(toRemove)
        uiView.addAnnotations(toAdd)

        // Refresh annotation views so colours/glyph text update after selection changes
        for pin in annotations {
            if let view = uiView.view(for: pin) as? MKMarkerAnnotationView {
                if vm.selectedAnnotation?.id == pin.id {
                    view.markerTintColor = .systemYellow
                    view.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
                    view.zPriority = .max
                } else {
                    view.markerTintColor = UIColor(pin.type.markerColor)
                    view.transform = .identity
                    view.zPriority = .defaultUnselected
                }
                // Keep checkpoint glyph numbers in sync
                if pin.type == .checkpoint, let number = vm.getCheckpointNumber(for: pin) {
                    view.glyphText = "\(number)"
                    view.glyphImage = nil
                }
            }
        }

        uiView.removeOverlays(uiView.overlays)
        uiView.addOverlays(routeSegments)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, vm: vm)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewBridge
        var vm: RouteCreationViewModel
        let segmentColors: [UIColor] = [
            .systemBlue, .systemGreen, .systemOrange,
            .systemPurple, .systemRed, .systemTeal, .systemIndigo
        ]

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
                    let touchPointInView = gestureRecognizer.location(in: view)
                    if view.bounds.contains(touchPointInView) {
                        tappedOnAnnotationView = true
                        mapView.selectAnnotation(annotation, animated: true)
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
                if !(view.annotation is MKUserLocation) { vm.selectAnnotation(nil) }
                return
            }
            if view.isDraggable && (view.dragState == .starting || view.dragState == .dragging) { return }
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

            // Use a stable, type-based reuse identifier so dequeuing and drag state work correctly
            let reuseIdentifier: String
            switch locationPin.type {
            case .start:      reuseIdentifier = "pin_start"
            case .checkpoint: reuseIdentifier = "pin_checkpoint"
            case .end:        reuseIdentifier = "pin_end"
            }

            let markerView: MKMarkerAnnotationView
            if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) as? MKMarkerAnnotationView {
                markerView = dequeued
                markerView.annotation = annotation
            } else {
                markerView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
            }

            // Long-press on the pin initiates dragging
            markerView.isDraggable = true
            markerView.canShowCallout = false

            if locationPin.type == .checkpoint, let number = vm.getCheckpointNumber(for: locationPin) {
                markerView.glyphText = "\(number)"
                markerView.glyphImage = nil
            } else {
                markerView.glyphText = nil
                markerView.glyphImage = UIImage(systemName: locationPin.type.icon)
            }

            if vm.selectedAnnotation?.id == locationPin.id {
                markerView.markerTintColor = UIColor.systemYellow
                markerView.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
                markerView.zPriority = .max
            } else {
                markerView.markerTintColor = UIColor(locationPin.type.markerColor)
                markerView.transform = .identity
                markerView.zPriority = .defaultUnselected
            }

            return markerView
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
            guard let pin = view.annotation as? LocationPin else { return }
            let coord = view.annotation!.coordinate
            var state: AnnotationDragState = .none

            switch newState {
            case .starting:
                state = .starting
                vm.selectAnnotation(pin)
                parent.onAnnotationDragStateChanged(pin, coord, state)
                return
            case .dragging:
                state = .dragging
                parent.onAnnotationDragStateChanged(pin, coord, state)
                return
            case .ending:  state = .ending
            case .canceling: state = .canceling
            case .none:
                if oldState == .dragging || oldState == .ending || oldState == .canceling { state = .none }
                else { return }
            @unknown default: return
            }
            parent.onAnnotationDragStateChanged(pin, coord, state)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                if let index = vm.routeSegments.firstIndex(where: { $0 === polyline }) {
                    renderer.strokeColor = segmentColors[index % segmentColors.count]
                } else {
                    renderer.strokeColor = .systemBlue
                }
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - UIColor + Color
extension UIColor {
    convenience init(_ color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if let cgColor = color.cgColor, let components = cgColor.components {
            let n = cgColor.numberOfComponents
            if n >= 3 { r = components[0]; g = components[1]; b = components[2]; a = components.count >= 4 ? components[3] : 1 }
            else if n == 2 { r = components[0]; g = components[0]; b = components[0]; a = components[1] }
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Route Created Success Overlay
struct RouteCreatedOverlay: View {
    let routeName: String
    let onGoHome: () -> Void

    @State private var checkmarkScale: CGFloat = 0
    @State private var contentOpacity: CGFloat = 0

    var body: some View {
        ZStack {
            // Blurred backdrop
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Animated checkmark
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 120, height: 120)
                    Circle()
                        .fill(Color.green.opacity(0.25))
                        .frame(width: 90, height: 90)
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.green)
                        .scaleEffect(checkmarkScale)
                }

                // Text
                VStack(spacing: 10) {
                    Text("Route Created!")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("\"\(routeName)\" has been saved\nand is ready to race.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .opacity(contentOpacity)

                // Buttons
                VStack(spacing: 12) {
                    Button(action: onGoHome) {
                        HStack(spacing: 10) {
                            Image(systemName: "house.fill")
                            Text("Go to Home")
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Button(action: onGoHome) {
                        Text("Race Now")
                            .fontWeight(.medium)
                            .font(.system(size: 15))
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 32)
                .opacity(contentOpacity)

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) {
                checkmarkScale = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.25)) {
                contentOpacity = 1
            }
        }
    }
}

// MARK: - Preview
#Preview {
    RouteCreationView()
        .environmentObject(AppState())
}
