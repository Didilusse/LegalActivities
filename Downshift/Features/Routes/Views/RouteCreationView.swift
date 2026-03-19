//
//  RouteCreationView.swift
//  Downshift
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
    @State private var savedRouteName: String? = nil
    
    // New states for enhanced features
    @State private var showQuickActions = false
    @State private var showSearchSheet = false
    @State private var showRoutePreview = false
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false

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
            VStack(spacing: 0) {
                topBar
                
                // Route stats card (shows when route has points)
                if vm.annotations.count >= 2 {
                    routeStatsCard
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
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
                    Spacer()
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
                    Spacer()
                }
            }

            if let notice = vm.routeCreationNotice {
                VStack {
                    Spacer()
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(notice)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture {
                    withAnimation {
                        vm.routeCreationNotice = nil
                    }
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
        .sheet(isPresented: $showSearchSheet) {
            addressSearchSheet
        }
        .sheet(isPresented: $showQuickActions) {
            quickActionsSheet
        }
        .sheet(isPresented: $showRoutePreview) {
            routePreviewSheet
        }
        .onChange(of: vm.routeSegments) {
            withAnimation { isCalculatingRoute = false }
        }
        .onChange(of: vm.annotations) {
            if vm.annotations.count >= 2 {
                withAnimation { isCalculatingRoute = true }
            }
        }
        .onChange(of: vm.routeCreationNotice) {
            guard vm.routeCreationNotice != nil else { return }
            Task {
                try? await Task.sleep(for: .seconds(5))
                await MainActor.run {
                    withAnimation {
                        vm.routeCreationNotice = nil
                    }
                }
            }
        }
        .animation(.spring(response: 0.4), value: vm.annotations.count)
    }

    // MARK: - Top Bar
    private var topBar: some View {
        ZStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        showSearchSheet = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    }

                    Button {
                        vm.zoomToFitRouteSegments(mapView: mapView)
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    }
                }
            }

            HStack(spacing: 4) {
                Button {
                    vm.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(vm.canUndo ? .primary : .secondary.opacity(0.5))
                        .frame(width: 40, height: 40)
                }
                .disabled(!vm.canUndo)

                Button {
                    vm.redo()
                } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(vm.canRedo ? .primary : .secondary.opacity(0.5))
                        .frame(width: 40, height: 40)
                }
                .disabled(!vm.canRedo)
            }
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
    }
    
    // MARK: - Route Stats Card
    private var routeStatsCard: some View {
        HStack(spacing: 16) {
            // Distance
            VStack(spacing: 2) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.blue)
                Text(formatDistance(vm.totalRouteDistance))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("Distance")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 32)
            
            // Estimated time
            VStack(spacing: 2) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)
                Text(formatDuration(vm.estimatedDuration))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("Est. Time")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 32)
            
            // Points count
            VStack(spacing: 2) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.green)
                Text("\(vm.annotations.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("Points")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
                .frame(height: 32)
            
            // Segments
            VStack(spacing: 2) {
                Image(systemName: "road.lanes")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.purple)
                Text("\(vm.routeSegments.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("Segments")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Bottom Panel
    private var bottomPanel: some View {
        VStack(spacing: 0) {
            // Handle indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)
            
            // Selected pin action bar
            if let selected = vm.selectedAnnotation {
                selectedPinBar(for: selected)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Divider
            if vm.selectedAnnotation != nil {
                Divider().opacity(0.3)
            }

            // Pin type selector with improved design
            pinTypeSelector

            // Quick actions row
            quickActionsRow
            
            // Main action row
            actionRow
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: -8)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.selectedAnnotation?.id)
    }

    // MARK: - Selected Pin Bar
    private func selectedPinBar(for pin: LocationPin) -> some View {
        HStack(spacing: 14) {
            // Pin type icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [pinTypeColor(pin.type), pinTypeColor(pin.type).opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: pin.type.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(pin.type == .start ? "Start Point" : pin.type == .end ? "Finish Point" : "Checkpoint \(vm.getCheckpointNumber(for: pin) ?? 0)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Text("Tap map to deselect • Long-press to drag")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                withAnimation { vm.removeSelectedAnnotation() }
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Color.red.gradient, in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Pin Type Selector
    private var pinTypeSelector: some View {
        HStack(spacing: 6) {
            PinTypeButton(
                icon: "flag.fill",
                label: "Start",
                color: .green,
                isSelected: selectedPointType == .start,
                hasPin: vm.annotations.contains { $0.type == .start }
            ) {
                withAnimation(.spring(response: 0.25)) {
                    selectedPointType = .start
                }
            }

            PinTypeButton(
                icon: "mappin.and.ellipse",
                label: "Checkpoint",
                color: .blue,
                isSelected: selectedPointType == .checkpoint,
                hasPin: !vm.checkpoints.isEmpty
            ) {
                withAnimation(.spring(response: 0.25)) {
                    selectedPointType = .checkpoint
                }
            }

            PinTypeButton(
                icon: "flag.checkered",
                label: "Finish",
                color: .red,
                isSelected: selectedPointType == .end,
                hasPin: vm.annotations.contains { $0.type == .end }
            ) {
                withAnimation(.spring(response: 0.25)) {
                    selectedPointType = .end
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    // MARK: - Quick Actions Row
    private var quickActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // My Location
                QuickActionButton(icon: "location.fill", label: "My Location", color: .blue) {
                    vm.centerMapOnUser(mapView: mapView)
                }
                
                // Checkpoints list
                if !vm.checkpoints.isEmpty {
                    QuickActionButton(
                        icon: "list.number",
                        label: "\(vm.checkpoints.count) Checkpoints",
                        color: .indigo
                    ) {
                        showCheckpointList = true
                    }
                }
                
                // Preview route
                if vm.canSaveRoute {
                    QuickActionButton(icon: "play.fill", label: "Preview", color: .purple) {
                        showRoutePreview = true
                    }
                }
                
                // Clear all
                if !vm.annotations.isEmpty {
                    QuickActionButton(icon: "trash", label: "Clear All", color: .red) {
                        showQuickActions = true
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Action Row
    private var actionRow: some View {
        HStack(spacing: 12) {
            // Hint text
            if vm.annotations.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Tap map to add a \(selectedPointType == .start ? "start" : selectedPointType == .end ? "finish" : "checkpoint") point")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 4)
            } else if vm.hasUnroutableSegments {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Adjust points so every segment follows a drivable road")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 4)
            } else if !vm.canSaveRoute {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(vm.annotations.contains { $0.type == .start } ? "Add a finish point" : "Add a start point")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 4)
            }

            Spacer()

            // Save button
            Button {
                showingSaveSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: vm.canSaveRoute ? "checkmark.circle.fill" : "exclamationmark.triangle")
                        .font(.system(size: 16, weight: .semibold))
                    Text(vm.canSaveRoute ? "Save Route" : "Route Not Ready")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background {
                    Capsule()
                        .fill(
                            vm.canSaveRoute
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [Color.blue, Color.blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                  ))
                                : AnyShapeStyle(Color.secondary.opacity(0.3))
                        )
                }
                .shadow(color: vm.canSaveRoute ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            }
            .disabled(!vm.canSaveRoute)
            .animation(.easeInOut(duration: 0.2), value: vm.canSaveRoute)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Checkpoint List Sheet
    private var checkpointListSheet: some View {
        NavigationStack {
            List {
                if vm.checkpoints.isEmpty {
                    ContentUnavailableView("No Checkpoints", systemImage: "mappin.slash", description: Text("Tap the map with 'Checkpoint' selected to add one."))
                } else {
                    ForEach(vm.checkpoints, id: \.id) { cp in
                        let number = vm.getCheckpointNumber(for: cp) ?? 0
                        let badgeColor = checkpointColor(for: number)
                        let isSelected = vm.selectedAnnotation?.id == cp.id
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
                                        .fill(badgeColor.gradient)
                                        .frame(width: 40, height: 40)
                                    Text("\(number)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Checkpoint \(number)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    Text(String(format: "%.5f, %.5f", cp.coordinate.latitude, cp.coordinate.longitude))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "location.circle")
                                    .foregroundStyle(badgeColor)
                                    .font(.title3)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 2)
                            .background(isSelected ? badgeColor.opacity(0.12) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
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
    
    // MARK: - Address Search Sheet
    private var addressSearchSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search for a place or address...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding()
                
                if isSearching {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("Try a different search term"))
                } else {
                    List(searchResults, id: \.self) { item in
                        Button {
                            placePin(at: item)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.red)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "Unknown")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                    
                                    if let address = item.placemark.title {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(spacing: 2) {
                                    Image(systemName: selectedPointType.icon)
                                        .font(.caption)
                                    Text("Add as")
                                        .font(.caption2)
                                    Text(selectedPointType == .start ? "Start" : selectedPointType == .end ? "Finish" : "CP")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(pinTypeColor(selectedPointType))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSearchSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Quick Actions Sheet
    private var quickActionsSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button(role: .destructive) {
                        vm.clearAll()
                        showQuickActions = false
                    } label: {
                        Label("Clear All Points", systemImage: "trash.fill")
                    }
                } footer: {
                    Text("This will remove all points from your route. You can undo this action.")
                }
            }
            .navigationTitle("Quick Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showQuickActions = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Route Preview Sheet
    private var routePreviewSheet: some View {
        NavigationStack {
            ZStack {
                // Preview map
                RoutePreviewMap(coordinates: vm.annotations.map { $0.coordinate }, routeSegments: vm.routeSegments)
                    .ignoresSafeArea()
                
                // Stats overlay
                VStack {
                    Spacer()
                    
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text(formatDistance(vm.totalRouteDistance))
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Distance")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 40)
                        
                        VStack(spacing: 4) {
                            Text(formatDuration(vm.estimatedDuration))
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Est. Time")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 40)
                        
                        VStack(spacing: 4) {
                            Text("\(vm.checkpoints.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Checkpoints")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .padding()
                }
            }
            .navigationTitle("Route Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showRoutePreview = false }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Helpers
    private func pinTypeColor(_ type: LocationPin.PointType) -> Color {
        switch type {
        case .start: return .green
        case .checkpoint: return .blue
        case .end: return .red
        }
    }

    private func checkpointColor(for number: Int) -> Color {
        let palette: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint]
        guard number > 0 else { return .blue }
        return palette[(number - 1) % palette.count]
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
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = mapView.region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            if let response = response {
                searchResults = response.mapItems
            }
        }
    }
    
    private func placePin(at mapItem: MKMapItem) {
        let coordinate = mapItem.placemark.coordinate
        vm.addAnnotation(at: coordinate, type: selectedPointType)
        
        // Zoom to the new location
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: true)
        
        showSearchSheet = false
        searchText = ""
        searchResults = []
    }
    
    private func formatDistance(_ meters: Double) -> String {
        appState.userProfile.unitPreference.formatDistance(meters)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}

// MARK: - Quick Action Button
private struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
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
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSelected ? color.gradient : color.opacity(0.1).gradient)
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(isSelected ? .white : color)
                    }
                    .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)

                    // Placed indicator
                    if hasPin {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(color)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                            .offset(x: 4, y: -4)
                    }
                }

                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? color : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Route Preview Map
struct RoutePreviewMap: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let routeSegments: [MKPolyline]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.isUserInteractionEnabled = true
        mapView.showsCompass = true
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        
        // Add annotations
        for (index, coord) in coordinates.enumerated() {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coord
            if index == 0 {
                annotation.title = "Start"
            } else if index == coordinates.count - 1 {
                annotation.title = "Finish"
            } else {
                annotation.title = "Checkpoint \(index)"
            }
            mapView.addAnnotation(annotation)
        }
        
        // Add route segments
        mapView.addOverlays(routeSegments)
        
        // Zoom to fit
        if !routeSegments.isEmpty {
            var zoomRect = MKMapRect.null
            routeSegments.forEach { segment in
                zoomRect = zoomRect.union(segment.boundingMapRect)
            }
            mapView.setVisibleMapRect(zoomRect, edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 120, right: 40), animated: false)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 5
                renderer.lineCap = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            
            let marker = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "preview")
            if annotation.title == "Start" {
                marker.markerTintColor = .systemGreen
                marker.glyphImage = UIImage(systemName: "flag.fill")
            } else if annotation.title == "Finish" {
                marker.markerTintColor = .systemRed
                marker.glyphImage = UIImage(systemName: "flag.checkered")
            } else {
                marker.markerTintColor = .systemBlue
            }
            return marker
        }
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

// MARK: - MapViewBridge
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
        let existing = uiView.annotations.compactMap { $0 as? LocationPin }
        let existingIDs = Set(existing.map { $0.id })
        let newIDs = Set(annotations.map { $0.id })

        let toRemove = existing.filter { !newIDs.contains($0.id) }
        let toAdd = annotations.filter { !existingIDs.contains($0.id) }

        uiView.removeAnnotations(toRemove)
        uiView.addAnnotations(toAdd)

        for pin in annotations {
            if let view = uiView.view(for: pin) as? MKMarkerAnnotationView {
                if vm.selectedAnnotation?.id == pin.id {
                    view.markerTintColor = .systemYellow
                    view.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
                    view.zPriority = .max
                } else {
                    if pin.type == .checkpoint, let number = vm.getCheckpointNumber(for: pin) {
                        view.markerTintColor = Coordinator.checkpointUIColor(for: number)
                    } else {
                        view.markerTintColor = UIColor(pin.type.markerColor)
                    }
                    view.transform = .identity
                    view.zPriority = .defaultUnselected
                }
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
                .systemGreen, .systemBlue, .systemOrange,
                .systemPurple, .systemRed, .systemTeal, .systemIndigo
            ]

            static func checkpointUIColor(for number: Int) -> UIColor {
                let palette: [UIColor] = [
                    .systemBlue,
                    .systemPurple,
                    .systemPink,
                    .systemOrange,
                    .systemTeal,
                    .systemIndigo,
                    .systemMint
                ]
                guard number > 0 else { return .systemBlue }
                return palette[(number - 1) % palette.count]
            }

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
                if locationPin.type == .checkpoint, let number = vm.getCheckpointNumber(for: locationPin) {
                    markerView.markerTintColor = Self.checkpointUIColor(for: number)
                } else {
                    markerView.markerTintColor = UIColor(locationPin.type.markerColor)
                }
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
                    renderer.strokeColor = .systemGreen
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
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

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
                        .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
