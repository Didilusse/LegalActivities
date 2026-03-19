//
//  HomeView.swift
//  Downshift
//
//  Home screen styled after a modern route-discovery layout:
//  hero banner → search → action chips → friend activity → your routes.
//

import SwiftUI


struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showFullFeed = false
    @State private var searchText = ""
    @State private var isSearching = false

    // MARK: - Time-of-day theming
    private var currentHour: Int { Calendar.current.component(.hour, from: Date()) }
    
    private enum TimeOfDay {
        case morning, afternoon, evening, night
        
        var primaryColors: [Color] {
            switch self {
            case .morning:
                return [
                    Color(red: 1.0, green: 0.6, blue: 0.2),
                    Color(red: 0.95, green: 0.4, blue: 0.3),
                    Color(red: 0.85, green: 0.25, blue: 0.4)
                ]
            case .afternoon:
                return [
                    Color(red: 0.15, green: 0.5, blue: 0.95),
                    Color(red: 0.1, green: 0.35, blue: 0.8),
                    Color(red: 0.2, green: 0.25, blue: 0.65)
                ]
            case .evening:
                return [
                    Color(red: 0.95, green: 0.45, blue: 0.2),
                    Color(red: 0.85, green: 0.25, blue: 0.35),
                    Color(red: 0.5, green: 0.15, blue: 0.5)
                ]
            case .night:
                return [
                    Color(red: 0.12, green: 0.15, blue: 0.35),
                    Color(red: 0.08, green: 0.08, blue: 0.25),
                    Color(red: 0.05, green: 0.05, blue: 0.18)
                ]
            }
        }
        
        var accentColor: Color {
            switch self {
            case .morning: return Color(red: 1.0, green: 0.85, blue: 0.4)
            case .afternoon: return Color(red: 0.4, green: 0.8, blue: 1.0)
            case .evening: return Color(red: 1.0, green: 0.6, blue: 0.3)
            case .night: return Color(red: 0.6, green: 0.5, blue: 1.0)
            }
        }
        
        var decorativeIcon: String {
            switch self {
            case .morning: return "sunrise.fill"
            case .afternoon: return "sun.max.fill"
            case .evening: return "sun.horizon.fill"
            case .night: return "moon.stars.fill"
            }
        }
    }
    
    private var timeOfDay: TimeOfDay {
        switch currentHour {
        case 5..<11: return .morning
        case 11..<17: return .afternoon
        case 17..<21: return .evening
        default: return .night
        }
    }

    private var greetingForHour: String {
        switch currentHour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Good night"
        }
    }

    static let heroBannerHeight: CGFloat = 280

    // MARK: - Hero Banner
    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            // Layered gradient background
            GeometryReader { geometry in
                ZStack {
                    // Base gradient
                    LinearGradient(
                        colors: timeOfDay.primaryColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Radial glow accent
                    RadialGradient(
                        colors: [
                            timeOfDay.accentColor.opacity(0.4),
                            timeOfDay.accentColor.opacity(0.1),
                            .clear
                        ],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 300
                    )
                    
                    // Secondary glow
                    RadialGradient(
                        colors: [
                            timeOfDay.primaryColors[0].opacity(0.3),
                            .clear
                        ],
                        center: .bottomLeading,
                        startRadius: 0,
                        endRadius: 250
                    )
                    
                    // Subtle noise/texture overlay
                    Rectangle()
                        .fill(.white.opacity(0.03))
                        .background(
                            Canvas { context, size in
                                // Create subtle dot pattern
                                for _ in 0..<50 {
                                    let x = CGFloat.random(in: 0..<size.width)
                                    let y = CGFloat.random(in: 0..<size.height)
                                    let rect = CGRect(x: x, y: y, width: 1, height: 1)
                                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.1)))
                                }
                            }
                        )
                    
                    // Bottom fade for content readability
                    LinearGradient(
                        colors: [.clear, .clear, .black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(height: geometry.size.height + 1000)
                .offset(y: -1000)
            }
            .ignoresSafeArea(edges: .all)
            
            // Decorative elements
            GeometryReader { geometry in
                // Large decorative icon
                Image(systemName: timeOfDay.decorativeIcon)
                    .font(.system(size: 120, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.15),
                                .white.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .position(x: geometry.size.width - 60, y: 80)
                
                // Abstract racing lines
                Path { path in
                    path.move(to: CGPoint(x: -20, y: geometry.size.height * 0.3))
                    path.addQuadCurve(
                        to: CGPoint(x: geometry.size.width + 20, y: geometry.size.height * 0.5),
                        control: CGPoint(x: geometry.size.width * 0.5, y: geometry.size.height * 0.15)
                    )
                }
                .stroke(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.1), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
                
                Path { path in
                    path.move(to: CGPoint(x: -20, y: geometry.size.height * 0.4))
                    path.addQuadCurve(
                        to: CGPoint(x: geometry.size.width + 20, y: geometry.size.height * 0.6),
                        control: CGPoint(x: geometry.size.width * 0.6, y: geometry.size.height * 0.25)
                    )
                }
                .stroke(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.06), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.5
                )
                
                // Small decorative circles
                Circle()
                    .fill(timeOfDay.accentColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)
                    .position(x: 40, y: 60)
                
                Circle()
                    .fill(timeOfDay.primaryColors[1].opacity(0.3))
                    .frame(width: 60, height: 60)
                    .blur(radius: 15)
                    .position(x: geometry.size.width - 100, y: geometry.size.height - 80)
            }

            // Text content at the bottom of the banner
            VStack(alignment: .leading, spacing: 8) {
                // Week stats badge
                let weekStats = appState.thisWeekStats()
                let units = appState.userProfile.unitPreference
                
                HStack(spacing: 8) {
                    if weekStats.distance > 0 {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                            Text(units.formatDistance(weekStats.distance))
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    
                    if weekStats.races > 0 {
                        HStack(spacing: 5) {
                            Image(systemName: "flag.checkered")
                                .font(.caption2)
                            Text("\(weekStats.races) race\(weekStats.races == 1 ? "" : "s")")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                }
                
                // Greeting
                Text(greetingForHour)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.8))
                
                // Name with gradient
                Text(appState.userProfile.name.isEmpty ? "Racer" : appState.userProfile.name)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(height: Self.heroBannerHeight)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroBanner
                    searchBar
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    quickActionChips
                    friendActivitySection
                    yourRoutesSection
                    Spacer(minLength: 32)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color(.systemBackground))
            .sheet(isPresented: $showFullFeed) {
                NavigationStack {
                    ActivityFeedView().environmentObject(appState)
                }
            }
            .onAppear { appState.loadRoutes() }
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        NavigationLink {
            SearchView().environmentObject(appState)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text("Search routes, friends and more")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Quick Action Chips
    private var quickActionChips: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick Actions")
                    .font(.title3).fontWeight(.bold)
                Spacer()
                NavigationLink {
                    RouteCreationView().environmentObject(appState)
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // New Route chip
                    NavigationLink {
                        RouteCreationView().environmentObject(appState)
                    } label: {
                        actionChip(
                            title: "New Route",
                            subtitle: "Design a path",
                            icon: "plus.circle.fill",
                            color: .blue
                        )
                    }
                    .buttonStyle(.plain)

                    // Start Racing chip
                    NavigationLink {
                        StartRacingView().environmentObject(appState)
                    } label: {
                        actionChip(
                            title: "Start Racing",
                            subtitle: appState.savedRoutes.isEmpty ? "No routes yet" : "\(appState.savedRoutes.count) route\(appState.savedRoutes.count == 1 ? "" : "s")",
                            icon: "flag.checkered",
                            color: .green
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.savedRoutes.isEmpty)
                    .opacity(appState.savedRoutes.isEmpty ? 0.5 : 1)

                    // Stats chip
                    NavigationLink {
                        StatsView().environmentObject(appState)
                    } label: {
                        actionChip(
                            title: "My Stats",
                            subtitle: "\(appState.userProfile.totalRaces) total races",
                            icon: "chart.bar.fill",
                            color: .purple
                        )
                    }
                    .buttonStyle(.plain)

                    // Recent best chip (if exists)
                    if let bestRoute = appState.savedRoutes.first(where: { !$0.raceHistory.isEmpty }),
                       let pb = appState.personalBest(for: bestRoute) {
                        NavigationLink {
                            RouteStatsView(route: bestRoute).environmentObject(appState)
                        } label: {
                            actionChip(
                                title: "Best on \(bestRoute.name)",
                                subtitle: formatShortDuration(pb),
                                icon: "trophy.fill",
                                color: .orange
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func actionChip(title: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(width: 130, height: 130)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - Friend Activity Section
    private var friendActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Friend Activity")
                    .font(.title3).fontWeight(.bold)
                Spacer()
                Button { showFullFeed = true } label: {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)

            if appState.activityFeed.isEmpty {
                emptyFriendActivity
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(appState.activityFeed.prefix(6))) { item in
                            activityCard(item)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func activityCard(_ item: ActivityFeedItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: item.iconName)
                    .font(.headline)
                    .foregroundStyle(activityColor(item.type))
                    .frame(width: 32, height: 32)
                    .background(activityColor(item.type).opacity(0.12))
                    .clipShape(Circle())
                Spacer()
                Text(item.relativeTimestamp)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 3) {
                Text(item.actorName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(item.routeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let dur = item.duration {
                    Text(formatShortDuration(dur))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(activityColor(item.type))
                }
            }
        }
        .padding(12)
        .frame(width: 140, height: 120)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private var emptyFriendActivity: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.2.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text("No activity yet")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Text("Add friends to see their races here")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func activityColor(_ type: ActivityType) -> Color {
        switch type {
        case .personalBestBeaten: return .yellow
        case .routeCompleted: return .green
        case .friendRaced: return .blue
        case .challengeAccepted: return .orange
        case .challengeCompleted: return .purple
        }
    }

    // MARK: - Your Routes Section
    private var yourRoutesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Routes")
                    .font(.title3).fontWeight(.bold)
                Spacer()
                NavigationLink {
                    StartRacingView().environmentObject(appState)
                } label: {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)

            if appState.savedRoutes.isEmpty {
                emptyRoutesView
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appState.savedRoutes.prefix(5).enumerated()), id: \.element.id) { index, route in
                        NavigationLink {
                            RouteStatsView(route: route).environmentObject(appState)
                        } label: {
                            routeRow(route: route)
                        }
                        .buttonStyle(.plain)

                        if index < min(appState.savedRoutes.count, 5) - 1 {
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }

    private func routeRow(route: SavedRoute) -> some View {
        HStack(spacing: 14) {
            // Colored icon tile
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(difficultyColor(route.difficulty).opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "map.fill")
                    .font(.title3)
                    .foregroundStyle(difficultyColor(route.difficulty))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(route.name)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(route.difficulty.rawValue)
                        .font(.caption)
                        .foregroundStyle(difficultyColor(route.difficulty))
                    if !route.raceHistory.isEmpty {
                        Text("·")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("\(route.raceHistory.count) race\(route.raceHistory.count == 1 ? "" : "s")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if let pb = appState.personalBest(for: route) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatShortDuration(pb))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("PB")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private var emptyRoutesView: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No routes yet")
                .font(.headline).foregroundStyle(.secondary)
            NavigationLink {
                RouteCreationView().environmentObject(appState)
            } label: {
                Text("Create Your First Route")
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func difficultyColor(_ d: Difficulty) -> Color {
        switch d {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}

// MARK: - Activity Feed Row (used by ActivityFeedView)
struct ActivityFeedRow: View {
    let item: ActivityFeedItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 36)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                if let dur = item.duration {
                    if item.type == .personalBestBeaten, let prev = item.previousBest {
                        Text("\(formatShortDuration(prev)) → \(formatShortDuration(dur))")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text(formatShortDuration(dur))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(item.relativeTimestamp)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var titleText: String {
        switch item.type {
        case .personalBestBeaten: return "\(item.actorName) beat PB on \(item.routeName)"
        case .routeCompleted:     return "\(item.actorName) completed \(item.routeName)"
        case .friendRaced:        return "\(item.actorName) raced \(item.routeName)"
        case .challengeAccepted:  return "\(item.actorName) accepted a challenge on \(item.routeName)"
        case .challengeCompleted: return "\(item.actorName) completed challenge on \(item.routeName)"
        }
    }

    private var iconColor: Color {
        switch item.type {
        case .personalBestBeaten: return .yellow
        case .routeCompleted:     return .green
        case .friendRaced:        return .blue
        case .challengeAccepted:  return .orange
        case .challengeCompleted: return .purple
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
