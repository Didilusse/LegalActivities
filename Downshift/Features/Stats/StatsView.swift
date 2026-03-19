//
//  StatsView.swift
//  Downshift
//
//  Shows all created routes and all raced routes with navigation into per-route stats.
//

import SwiftUI

struct StatsView: View {
    @EnvironmentObject var appState: AppState

    // Routes the user created (all of them)
    private var createdRoutes: [SavedRoute] {
        appState.savedRoutes.sorted { $0.createdDate > $1.createdDate }
    }

    // Routes the user has actually raced at least once
    private var racedRoutes: [SavedRoute] {
        appState.savedRoutes
            .filter { !$0.raceHistory.isEmpty }
            .sorted {
                let a = $0.raceHistory.max(by: { $0.date < $1.date })?.date ?? $0.createdDate
                let b = $1.raceHistory.max(by: { $0.date < $1.date })?.date ?? $1.createdDate
                return a > b
            }
    }

    private var units: UnitPreference { appState.userProfile.unitPreference }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                summaryCard
                routeSection(
                    title: "Raced Routes",
                    icon: "flag.checkered",
                    color: .green,
                    routes: racedRoutes,
                    emptyMessage: "You haven't raced any routes yet. Start Racing to record your first result."
                )
                routeSection(
                    title: "Created Routes",
                    icon: "plus.circle.fill",
                    color: .blue,
                    routes: createdRoutes,
                    emptyMessage: "You haven't created any routes yet. Use New Route to create your first one."
                )
            }
            .padding(.vertical)
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Summary Card
    private var summaryCard: some View {
        let allResults = appState.savedRoutes.flatMap { $0.raceHistory }
        let totalDist = allResults.reduce(0) { $0 + $1.totalDistance }
        let totalTime = allResults.reduce(0) { $0 + $1.totalDuration }

        return VStack(alignment: .leading, spacing: 12) {
            Label("Your Overview", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundStyle(.primary)

            Divider()

            HStack(spacing: 0) {
                summaryItem(value: "\(appState.userProfile.totalRaces)", label: "Total Races")
                Divider().frame(height: 40)
                summaryItem(value: units.formatDistance(totalDist), label: "Total Distance")
                Divider().frame(height: 40)
                summaryItem(value: formatShortDuration(totalTime), label: "Total Time")
            }

            Divider()

            HStack(spacing: 0) {
                summaryItem(value: "\(createdRoutes.count)", label: "Routes Created")
                Divider().frame(height: 40)
                summaryItem(value: "\(racedRoutes.count)", label: "Routes Raced")
                Divider().frame(height: 40)
                let bestSpd = appState.userProfile.bestAvgSpeed
                summaryItem(value: bestSpd > 0 ? units.formatSpeed(bestSpd) : "—", label: "Best Speed")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }

    private func summaryItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Route Section
    private func routeSection(
        title: String,
        icon: String,
        color: Color,
        routes: [SavedRoute],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(routes.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            if routes.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                        NavigationLink {
                            RouteStatsView(route: route)
                                .environmentObject(appState)
                        } label: {
                            routeRow(route: route, isRacedSection: title == "Raced Routes")
                        }
                        .buttonStyle(.plain)

                        if index < routes.count - 1 {
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Route Row
    private func routeRow(route: SavedRoute, isRacedSection: Bool) -> some View {
        HStack(spacing: 12) {
            // Difficulty color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(difficultyColor(route.difficulty))
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(route.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if isRacedSection {
                        if let pb = appState.personalBest(for: route) {
                            Label(formatShortDuration(pb), systemImage: "trophy.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(route.raceHistory.count) race\(route.raceHistory.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(route.difficulty.rawValue)
                            .font(.caption)
                            .foregroundStyle(difficultyColor(route.difficulty))
                        if !route.tags.isEmpty {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(route.tags.prefix(2).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Spacer()

            // Racer count badge
            let racerCount = racersForRoute(route)
            if racerCount > 0 {
                VStack(spacing: 2) {
                    Text("\(racerCount)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(racerCount == 1 ? "racer" : "racers")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func racersForRoute(_ route: SavedRoute) -> Int {
        var count = route.raceHistory.isEmpty ? 0 : 1  // user counts if raced
        count += appState.friends.filter { friend in
            friend.recentRaces.contains { $0.routeId == route.id }
        }.count
        return count
    }

    private func difficultyColor(_ d: Difficulty) -> Color {
        switch d {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}

#Preview {
    NavigationStack {
        StatsView()
            .environmentObject(AppState())
    }
}
