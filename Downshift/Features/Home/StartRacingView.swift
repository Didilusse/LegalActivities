//
//  StartRacingView.swift
//  Downshift
//
//  Full-screen route selection pushed from HomeView's NavigationStack.
//  Tapping a route opens RoutePreviewSheet; the sheet's Race button pushes RaceInProgressView.
//

import SwiftUI
import MapKit

// MARK: - Sort Options
enum RouteSortOption: String, CaseIterable {
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case distanceAsc = "Distance (Short)"
    case distanceDesc = "Distance (Long)"
    case recentlyCreated = "Recently Created"
    case mostRaced = "Most Raced"
    case bestTime = "Has Personal Best"
}

// MARK: - Race Configuration (for navigation)
struct RaceConfiguration: Hashable {
    let route: SavedRoute
    let reversed: Bool
}

// MARK: - Distance Filter
enum DistanceFilter: CaseIterable {
    case all
    case short
    case medium
    case long
    
    func matches(distance: Double) -> Bool {
        switch self {
        case .all: return true
        case .short: return distance < 5000
        case .medium: return distance >= 5000 && distance <= 15000
        case .long: return distance > 15000
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "arrow.left.and.right"
        case .short: return "hare.fill"
        case .medium: return "figure.run"
        case .long: return "tortoise.fill"
        }
    }
    
    func displayName(for units: UnitPreference) -> String {
        switch self {
        case .all:
            return "Any Distance"
        case .short:
            return units == .metric ? "< 5 km" : "< 3 mi"
        case .medium:
            return units == .metric ? "5-15 km" : "3-10 mi"
        case .long:
            return units == .metric ? "> 15 km" : "> 10 mi"
        }
    }
}

struct StartRacingView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // One shared LocationManager for whichever route the user picks
    @StateObject private var locationManager = LocationManager()

    // Search and filter state
    @State private var searchText = ""
    @State private var selectedDifficulty: Difficulty? = nil
    @State private var selectedDistanceFilter: DistanceFilter = .all
    @State private var selectedTags: Set<String> = []
    @State private var sortOption: RouteSortOption = .recentlyCreated
    @State private var showFilters = false
    @State private var showSortOptions = false

    // Sheet state
    @State private var previewRoute: SavedRoute? = nil
    // Set when user taps Race in the sheet; triggers navigation
    @State private var activeRaceConfig: RaceConfiguration? = nil

    // Computed: all unique tags across routes
    private var allTags: [String] {
        Array(Set(appState.savedRoutes.flatMap { $0.tags })).sorted()
    }
    
    // Active filter count for badge
    private var activeFilterCount: Int {
        var count = 0
        if selectedDifficulty != nil { count += 1 }
        if selectedDistanceFilter != .all { count += 1 }
        if !selectedTags.isEmpty { count += selectedTags.count }
        return count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroHeader
                searchAndFiltersSection

                if !appState.savedRoutes.isEmpty {
                    quickStatsSection
                }

                routesContent
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Select a Route")
                    .font(.headline)
            }
        }
        .onAppear {
            appState.loadRoutes()
        }
        .navigationDestination(isPresented: Binding(
            get: { activeRaceConfig != nil },
            set: { if !$0 { activeRaceConfig = nil } }
        )) {
            if let config = activeRaceConfig {
                RaceInProgressView(route: config.route, locationManager: locationManager, units: appState.userProfile.unitPreference, reversed: config.reversed)
                    .environmentObject(appState)
                    .onDisappear {
                        appState.loadRoutes()
                    }
            }
        }
        .navigationDestination(item: $previewRoute) { route in
            RoutePreviewSheet(
                route: route,
                locationManager: locationManager,
                onStartRace: { reversed in
                    activeRaceConfig = RaceConfiguration(route: route, reversed: reversed)
                }
            )
            .environmentObject(appState)
        }
        // Sort options sheet
        .sheet(isPresented: $showSortOptions) {
            sortOptionsSheet
        }
        // Filters sheet
        .sheet(isPresented: $showFilters) {
            filtersSheet
        }
    }
    
    // MARK: - Hero Header
    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background with infinite upward extension
            GeometryReader { geometry in
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.6, blue: 0.4),
                        Color(red: 0.05, green: 0.4, blue: 0.35),
                        Color(red: 0.02, green: 0.25, blue: 0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Extend the gradient upward by adding extra height
                .frame(height: geometry.size.height + 1000)
                .offset(y: -1000) // Shift it up so the extra extends above
            }
            .ignoresSafeArea(edges: .top)
            
            // Racing pattern overlay (outside GeometryReader so it doesn't get offset)
            Image(systemName: "flag.checkered")
                .font(.system(size: 200))
                .foregroundStyle(.white.opacity(0.05))
                .rotationEffect(.degrees(-15))
                .offset(x: 100, y: -30)
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                // Icon badge
                Image(systemName: "flag.checkered.2.crossed")
                    .font(.title)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready to Race?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Text("Choose a route and beat your personal best")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(20)
            .padding(.bottom, 8)
        }
        .frame(height: 180)
    }
    
    // MARK: - Search and Filters Section
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("Search by name, location, tag...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Filter button
                Button {
                    showFilters = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundStyle(activeFilterCount > 0 ? .white : .primary)
                            .frame(width: 44, height: 44)
                            .background(activeFilterCount > 0 ? Color.blue : Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        if activeFilterCount > 0 {
                            Text("\(activeFilterCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                        }
                    }
                }
                
                // Sort button
                Button {
                    showSortOptions = true
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Quick filter chips (horizontal scroll)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Difficulty chips
                    QuickFilterChip(
                        title: "All",
                        isSelected: selectedDifficulty == nil,
                        color: .blue
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedDifficulty = nil
                        }
                    }
                    
                    ForEach(Difficulty.allCases, id: \.self) { diff in
                        QuickFilterChip(
                            title: diff.rawValue,
                            isSelected: selectedDifficulty == diff,
                            color: difficultyColor(diff)
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedDifficulty = selectedDifficulty == diff ? nil : diff
                            }
                        }
                    }
                    
                    Divider()
                        .frame(height: 24)
                        .padding(.horizontal, 4)
                    
                    // Distance chips
                    ForEach(DistanceFilter.allCases.filter { $0 != .all }, id: \.self) { filter in
                        QuickFilterChip(
                            title: filter.displayName(for: appState.userProfile.unitPreference),
                            icon: filter.icon,
                            isSelected: selectedDistanceFilter == filter,
                            color: .purple
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedDistanceFilter = selectedDistanceFilter == filter ? .all : filter
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
            
            // Active filters display
            if activeFilterCount > 0 || !searchText.isEmpty {
                activeFiltersBar
            }
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Active Filters Bar
    private var activeFiltersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !searchText.isEmpty {
                    ActiveFilterTag(
                        label: "Search: \"\(searchText)\"",
                        color: .gray
                    ) {
                        searchText = ""
                    }
                }
                
                if let diff = selectedDifficulty {
                    ActiveFilterTag(
                        label: diff.rawValue,
                        color: difficultyColor(diff)
                    ) {
                        selectedDifficulty = nil
                    }
                }
                
                if selectedDistanceFilter != .all {
                    ActiveFilterTag(
                        label: selectedDistanceFilter.displayName(for: appState.userProfile.unitPreference),
                        color: .purple
                    ) {
                        selectedDistanceFilter = .all
                    }
                }
                
                ForEach(Array(selectedTags), id: \.self) { tag in
                    ActiveFilterTag(
                        label: "#\(tag)",
                        color: .orange
                    ) {
                        selectedTags.remove(tag)
                    }
                }
                
                // Clear all button
                Button {
                    withAnimation {
                        searchText = ""
                        selectedDifficulty = nil
                        selectedDistanceFilter = .all
                        selectedTags.removeAll()
                    }
                } label: {
                    Text("Clear All")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                }
                .padding(.leading, 4)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }
    
    // MARK: - Quick Stats Section
    private var quickStatsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatCard(
                    icon: "map.fill",
                    value: "\(appState.savedRoutes.count)",
                    label: "Total Routes",
                    color: .blue
                )
                
                StatCard(
                    icon: "trophy.fill",
                    value: "\(appState.savedRoutes.filter { appState.personalBest(for: $0) != nil }.count)",
                    label: "With PB",
                    color: .orange
                )
                
                let totalDistance = appState.savedRoutes.reduce(0) { $0 + $1.totalDistance }
                StatCard(
                    icon: "arrow.left.and.right",
                    value: appState.userProfile.unitPreference.formatDistance(totalDistance),
                    label: "Total Distance",
                    color: .green
                )
                
                let totalRaces = appState.savedRoutes.reduce(0) { $0 + $1.raceHistory.count }
                StatCard(
                    icon: "flag.checkered",
                    value: "\(totalRaces)",
                    label: "Total Races",
                    color: .purple
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Routes Content
    private var routesContent: some View {
        VStack(spacing: 16) {
            if appState.savedRoutes.isEmpty {
                emptyView
            } else if filteredRoutes.isEmpty {
                noResultsView
            } else {
                // Recent Routes Section (if not filtering)
                if searchText.isEmpty && selectedDifficulty == nil && selectedDistanceFilter == .all && selectedTags.isEmpty {
                    if !appState.recentRoutes.isEmpty {
                        routeSection(title: "Recent Routes", icon: "clock.fill", routes: appState.recentRoutes)
                    }
                }
                
                // All/Filtered Routes Section
                let sectionTitle = activeFilterCount > 0 || !searchText.isEmpty ? "Results (\(filteredRoutes.count))" : "All Routes"
                routeSection(title: sectionTitle, icon: "map.fill", routes: filteredRoutes)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 32)
    }
    
    // MARK: - Route Section
    private func routeSection(title: String, icon: String, routes: [SavedRoute]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(routes) { route in
                    RouteCard(
                        route: route,
                        personalBest: appState.personalBest(for: route),
                        unitPreference: appState.userProfile.unitPreference
                    ) {
                        previewRoute = route
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("No Routes Yet")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Create a route first, then come back to race it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            NavigationLink {
                RouteCreationView().environmentObject(appState)
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Your First Route")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.blue)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .padding(.top, 40)
    }
    
    // MARK: - No Results View
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("No Routes Found")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Try adjusting your search or filters")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Button {
                withAnimation {
                    searchText = ""
                    selectedDifficulty = nil
                    selectedDistanceFilter = .all
                    selectedTags.removeAll()
                }
            } label: {
                Text("Clear Filters")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .padding(.top, 20)
    }
    
    // MARK: - Sort Options Sheet
    private var sortOptionsSheet: some View {
        NavigationStack {
            List {
                ForEach(RouteSortOption.allCases, id: \.self) { option in
                    Button {
                        sortOption = option
                        showSortOptions = false
                    } label: {
                        HStack {
                            Text(option.rawValue)
                                .foregroundStyle(.primary)
                            Spacer()
                            if sortOption == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sort By")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showSortOptions = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Filters Sheet
    private var filtersSheet: some View {
        NavigationStack {
            List {
                // Difficulty Section
                Section("Difficulty") {
                    ForEach(Difficulty.allCases, id: \.self) { diff in
                        Button {
                            if selectedDifficulty == diff {
                                selectedDifficulty = nil
                            } else {
                                selectedDifficulty = diff
                            }
                        } label: {
                            HStack {
                                Circle()
                                    .fill(difficultyColor(diff))
                                    .frame(width: 12, height: 12)
                                Text(diff.rawValue)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedDifficulty == diff {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
                
                // Distance Section
                Section("Distance") {
                    ForEach(DistanceFilter.allCases, id: \.self) { filter in
                        Button {
                            selectedDistanceFilter = filter
                        } label: {
                            HStack {
                                Image(systemName: filter.icon)
                                    .frame(width: 24)
                                Text(filter.displayName(for: appState.userProfile.unitPreference))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedDistanceFilter == filter {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
                
                // Tags Section
                if !allTags.isEmpty {
                    Section("Tags") {
                        ForEach(allTags, id: \.self) { tag in
                            Button {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "tag.fill")
                                        .foregroundStyle(.orange)
                                        .frame(width: 24)
                                    Text(tag)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedTags.contains(tag) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        selectedDifficulty = nil
                        selectedDistanceFilter = .all
                        selectedTags.removeAll()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showFilters = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Helpers
    private var filteredRoutes: [SavedRoute] {
        var routes = appState.savedRoutes
        
        // Search filter (searches name, tags, location, and formatted distance)
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            routes = routes.filter { route in
                // Match name
                if route.name.lowercased().contains(searchLower) { return true }
                // Match tags
                if route.tags.contains(where: { $0.lowercased().contains(searchLower) }) { return true }
                // Match difficulty
                if route.difficulty.rawValue.lowercased().contains(searchLower) { return true }
                // Match location
                if let location = route.location, location.lowercased().contains(searchLower) { return true }
                // Match distance (e.g., "5 km", "3 mi")
                let formattedDistance = appState.userProfile.unitPreference.formatDistance(route.totalDistance).lowercased()
                if formattedDistance.contains(searchLower) { return true }
                return false
            }
        }
        
        // Difficulty filter
        if let diff = selectedDifficulty {
            routes = routes.filter { $0.difficulty == diff }
        }
        
        // Distance filter
        if selectedDistanceFilter != .all {
            routes = routes.filter { selectedDistanceFilter.matches(distance: $0.totalDistance) }
        }
        
        // Tags filter
        if !selectedTags.isEmpty {
            routes = routes.filter { route in
                !selectedTags.isDisjoint(with: Set(route.tags))
            }
        }
        
        // Sorting
        switch sortOption {
        case .nameAsc:
            routes.sort { $0.name.lowercased() < $1.name.lowercased() }
        case .nameDesc:
            routes.sort { $0.name.lowercased() > $1.name.lowercased() }
        case .distanceAsc:
            routes.sort { $0.totalDistance < $1.totalDistance }
        case .distanceDesc:
            routes.sort { $0.totalDistance > $1.totalDistance }
        case .recentlyCreated:
            routes.sort { $0.createdDate > $1.createdDate }
        case .mostRaced:
            routes.sort { $0.raceHistory.count > $1.raceHistory.count }
        case .bestTime:
            routes.sort { route1, route2 in
                let pb1 = appState.personalBest(for: route1)
                let pb2 = appState.personalBest(for: route2)
                if pb1 != nil && pb2 == nil { return true }
                if pb1 == nil && pb2 != nil { return false }
                return (pb1 ?? .infinity) < (pb2 ?? .infinity)
            }
        }
        
        return routes
    }

    private func difficultyColor(_ difficulty: Difficulty) -> Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}

// MARK: - Route Card Component
struct RouteCard: View {
    let route: SavedRoute
    let personalBest: TimeInterval?
    let unitPreference: UnitPreference
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Mini map preview
                RouteMapPreview(coordinates: route.clCoordinates)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                    )
                    .overlay(alignment: .topTrailing) {
                        // Difficulty badge
                        DifficultyBadge(difficulty: route.difficulty)
                            .padding(8)
                    }
                
                // Route info
                VStack(alignment: .leading, spacing: 10) {
                    // Title and chevron
                    HStack {
                        Text(route.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    // Location (if available)
                    if let location = route.location {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.secondary)
                            Text(location)
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                    
                    // Stats row
                    HStack(spacing: 16) {
                        // Distance
                        Label(unitPreference.formatDistance(route.totalDistance), systemImage: "arrow.left.and.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // Race count
                        if route.raceHistory.count > 0 {
                            Label("\(route.raceHistory.count) race\(route.raceHistory.count == 1 ? "" : "s")", systemImage: "flag.checkered")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // Personal best
                        if let pb = personalBest {
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.orange)
                                Text(formatShortDuration(pb))
                                    .fontWeight(.semibold)
                            }
                            .font(.caption)
                            .foregroundStyle(.primary)
                        }
                    }
                    
                    // Tags
                    if !route.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(route.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(14)
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Route Map Preview
struct RouteMapPreview: View {
    let coordinates: [CLLocationCoordinate2D]
    
    var body: some View {
        if coordinates.count >= 2 {
            Map(interactionModes: []) {
                MapPolyline(coordinates: coordinates)
                    .stroke(.blue, lineWidth: 3)

                if let first = coordinates.first {
                    Annotation("Start", coordinate: first) {
                        Circle()
                            .fill(.green)
                            .frame(width: 10, height: 10)
                    }
                }

                if let last = coordinates.last {
                    Annotation("End", coordinate: last) {
                        Circle()
                            .fill(.red)
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat))
        } else {
            Rectangle()
                .fill(Color(.tertiarySystemBackground))
                .overlay {
                    Image(systemName: "map")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                }
        }
    }
}

// MARK: - Quick Filter Chip
struct QuickFilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.tertiarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Active Filter Tag
struct ActiveFilterTag: View {
    let label: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 110)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Shared Components (kept for compatibility)
struct DifficultyBadge: View {
    let difficulty: Difficulty

    var body: some View {
        Text(difficulty.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.9))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(color: badgeColor.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    private var badgeColor: Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    NavigationStack {
        StartRacingView()
            .environmentObject(AppState())
    }
}
