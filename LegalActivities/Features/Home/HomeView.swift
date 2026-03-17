//
//  HomeView.swift
//  LegalActivities
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

    // MARK: - Time-of-day gradient
    private var currentHour: Int { Calendar.current.component(.hour, from: Date()) }

    private var timeOfDayGradient: LinearGradient {
        let h = currentHour
        let colors: [Color]
        switch h {
        case 5..<11:   // Morning — warm amber / peach sky
            colors = [
                Color(red: 0.90, green: 0.45, blue: 0.15),
                Color(red: 0.95, green: 0.62, blue: 0.30),
                Color(red: 0.70, green: 0.40, blue: 0.55)
            ]
        case 11..<17:  // Afternoon — bright blue sky
            colors = [
                Color(red: 0.10, green: 0.38, blue: 0.72),
                Color(red: 0.20, green: 0.55, blue: 0.82),
                Color(red: 0.15, green: 0.65, blue: 0.70)
            ]
        case 17..<21:  // Evening — sunset orange / purple
            colors = [
                Color(red: 0.65, green: 0.20, blue: 0.45),
                Color(red: 0.90, green: 0.40, blue: 0.20),
                Color(red: 0.95, green: 0.60, blue: 0.25)
            ]
        default:       // Night — deep navy / indigo
            colors = [
                Color(red: 0.05, green: 0.05, blue: 0.22),
                Color(red: 0.10, green: 0.10, blue: 0.38),
                Color(red: 0.18, green: 0.12, blue: 0.45)
            ]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var greetingForHour: String {
        switch currentHour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Good night"
        }
    }

    static let heroBannerHeight: CGFloat = 260

    // MARK: - Hero Banner
    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background with infinite upward extension
            GeometryReader { geometry in
                timeOfDayGradient
                    .overlay(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    // Extend the gradient upward by adding extra height
                    .frame(height: geometry.size.height + 1000)
                    .offset(y: -1000) // Shift it up so the extra extends above
            }
            .ignoresSafeArea(edges: .all)

            // Text content at the bottom of the banner
            VStack(alignment: .leading, spacing: 4) {
                let weekStats = appState.thisWeekStats()
                let units = appState.userProfile.unitPreference
                if weekStats.distance > 0 {
                    Label(units.formatDistance(weekStats.distance) + " this week", systemImage: "flame.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                Text("\(greetingForHour), \(appState.userProfile.name.isEmpty ? "Racer" : appState.userProfile.name)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
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
