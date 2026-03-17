//
//  RouteStatsView.swift
//  LegalActivities
//
//  Per-route stats screen showing all racers (user + friends) and their times.
//

import SwiftUI
import MapKit

struct RouteStatsView: View {
    let route: SavedRoute
    @EnvironmentObject var appState: AppState

    // Build a unified list of all racers for this route, sorted by best time
    private var racerEntries: [RacerEntry] {
        var entries: [RacerEntry] = []

        // Your own results
        let myResults = route.raceHistory
        if !myResults.isEmpty {
            let best = myResults.min(by: { $0.totalDuration < $1.totalDuration })!
            let avgSpd = myResults.map { $0.averageSpeed }.reduce(0, +) / Double(myResults.count)
            let last = myResults.max(by: { $0.date < $1.date })!.date
            entries.append(RacerEntry(
                name: appState.userProfile.name,
                avatarSystemName: appState.userProfile.avatarSystemName,
                bestTime: best.totalDuration,
                totalRaces: myResults.count,
                avgSpeed: avgSpd,
                lastRaced: last,
                isYou: true
            ))
        }

        // Friends who raced this route
        for friend in appState.friends {
            let friendRaces = friend.recentRaces.filter { $0.routeId == route.id }
            guard !friendRaces.isEmpty else { continue }
            let best = friendRaces.min(by: { $0.totalDuration < $1.totalDuration })!
            let avgSpd = friendRaces.map { $0.averageSpeed }.reduce(0, +) / Double(friendRaces.count)
            let last = friendRaces.max(by: { $0.date < $1.date })!.date
            entries.append(RacerEntry(
                name: friend.name,
                avatarSystemName: friend.avatarSystemName,
                bestTime: best.totalDuration,
                totalRaces: friendRaces.count,
                avgSpeed: avgSpd,
                lastRaced: last,
                isYou: false
            ))
        }

        return entries.sorted { $0.bestTime < $1.bestTime }
    }

    private var units: UnitPreference { appState.userProfile.unitPreference }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                routeHeaderCard
                routeMapCard
                routeInfoCard
                overallStatsCard
                leaderboardSection
                raceHistorySection
            }
            .padding(.vertical)
        }
        .navigationTitle(route.name)
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Map Card
    private var routeMapCard: some View {
        RouteOverviewMap(route: route)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
            .overlay(alignment: .bottomLeading) {
                Label(units.formatDistance(route.totalDistance), systemImage: "arrow.left.and.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(10)
            }
            .overlay(alignment: .bottomTrailing) {
                Label(estimatedTimeString, systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(10)
            }
            .padding(.horizontal)
    }

    // MARK: - Route Info Card (distance, est. time, checkpoints, created by)
    private var routeInfoCard: some View {
        VStack(spacing: 0) {
            // Distance · Est. time · Checkpoints row
            HStack(spacing: 0) {
                routeInfoCell(
                    value: units.formatDistance(route.totalDistance),
                    label: "Distance",
                    icon: "arrow.left.and.right",
                    color: .blue
                )
                Divider().frame(height: 40)
                routeInfoCell(
                    value: estimatedTimeString,
                    label: "Est. Time",
                    icon: "clock.fill",
                    color: .purple
                )
                Divider().frame(height: 40)
                let checkpoints = max(0, route.coordinates.count - 2)
                routeInfoCell(
                    value: "\(checkpoints)",
                    label: checkpoints == 1 ? "Checkpoint" : "Checkpoints",
                    icon: "mappin.circle.fill",
                    color: .orange
                )
            }
            .padding(.vertical, 12)

            Divider().padding(.horizontal)

            // Created by row
            HStack(spacing: 12) {
                Image(systemName: appState.userProfile.avatarSystemName)
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 38, height: 38)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Created by")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(appState.userProfile.name.isEmpty ? "You" : appState.userProfile.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                Text(route.createdDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }

    private func routeInfoCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var estimatedTimeString: String {
        let t = route.estimatedDuration
        let m = Int(t) / 60
        if m < 60 { return "\(m) min" }
        let h = m / 60
        let rem = m % 60
        return rem == 0 ? "\(h) hr" : "\(h)h \(rem)m"
    }

    // MARK: - Route Header Card
    private var routeHeaderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                difficultyBadge
                ForEach(route.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                }
                Spacer()
            }

            Divider()

            HStack(spacing: 0) {
                infoItem(value: "\(route.raceHistory.count)", label: "Your Races")
                Divider().frame(height: 40)
                if let pb = appState.personalBest(for: route) {
                    infoItem(value: formatShortDuration(pb), label: "Your PB")
                } else {
                    infoItem(value: "—", label: "Your PB")
                }
                Divider().frame(height: 40)
                infoItem(value: "\(racerEntries.count)", label: "Total Racers")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }

    private var difficultyBadge: some View {
        Text(route.difficulty.rawValue)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(difficultyColor(route.difficulty).opacity(0.15))
            .foregroundStyle(difficultyColor(route.difficulty))
            .clipShape(Capsule())
    }

    // MARK: - Overall Stats Card
    @ViewBuilder
    private var overallStatsCard: some View {
        let allTimes = racerEntries.map { $0.bestTime }
        if !allTimes.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Overall Stats", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Divider()

                HStack(spacing: 0) {
                    infoItem(value: formatShortDuration(allTimes.min()!), label: "Course Record")
                    Divider().frame(height: 40)
                    infoItem(
                        value: formatShortDuration(allTimes.reduce(0, +) / Double(allTimes.count)),
                        label: "Avg Best Time"
                    )
                    Divider().frame(height: 40)
                    infoItem(
                        value: "\(racerEntries.map { $0.totalRaces }.reduce(0, +))",
                        label: "Total Races"
                    )
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            .padding(.horizontal)
        }
    }

    // MARK: - Leaderboard Section
    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Leaderboard")
                .font(.headline)
                .padding(.horizontal)

            if racerEntries.isEmpty {
                emptyLeaderboard
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(racerEntries.enumerated()), id: \.offset) { index, entry in
                        racerRow(rank: index + 1, entry: entry)
                        if index < racerEntries.count - 1 {
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

    private var emptyLeaderboard: some View {
        VStack(spacing: 10) {
            Image(systemName: "flag.checkered.2.crossed")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No races yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Race this route or add friends to populate the leaderboard.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Racer Row
    private func racerRow(rank: Int, entry: RacerEntry) -> some View {
        HStack(spacing: 12) {
            // Rank badge
            ZStack {
                Circle()
                    .fill(rankColor(rank))
                    .frame(width: 28, height: 28)
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(rank <= 3 ? .white : .primary)
            }

            Image(systemName: entry.avatarSystemName)
                .font(.title2)
                .foregroundStyle(entry.isYou ? .blue : .secondary)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.isYou ? appState.userProfile.name : entry.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(entry.isYou ? .blue : .primary)
                    if entry.isYou {
                        Text("You")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                Text("\(entry.totalRaces) race\(entry.totalRaces == 1 ? "" : "s") · \(units.formatSpeed(entry.avgSpeed)) avg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatShortDuration(entry.bestTime))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(rank == 1 ? Color(red: 0.8, green: 0.65, blue: 0.1) : .primary)
                Text("best")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(entry.isYou ? Color.blue.opacity(0.04) : Color.clear)
    }

    // MARK: - Race History Section
    private var raceHistorySection: some View {
        let history = route.raceHistory.sorted { $0.date > $1.date }
        let pb = appState.personalBest(for: route)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your Race History")
                    .font(.headline)
                Spacer()
                Text("\(history.count) run\(history.count == 1 ? "" : "s")")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            if history.isEmpty {
                Text("You haven't raced this route yet.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(history.enumerated()), id: \.element.id) { index, result in
                        NavigationLink {
                            RaceResultDetailView(result: result, route: route)
                                .environmentObject(appState)
                        } label: {
                            historyRow(result: result, isPB: result.totalDuration == pb)
                        }
                        .buttonStyle(.plain)
                        if index < history.count - 1 {
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

    private func historyRow(result: RaceResult, isPB: Bool) -> some View {
        HStack(spacing: 14) {
            // Date column
            VStack(alignment: .center, spacing: 2) {
                Text(result.date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(result.date.formatted(.dateTime.year()))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: 44)

            Divider().frame(height: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(formatShortDuration(result.totalDuration))
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    if isPB {
                        Text("PB")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                }
                Text(units.formatDistance(result.totalDistance) + " · " + units.formatSpeed(result.averageSpeed) + " avg")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers
    private func infoItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 0.85, green: 0.73, blue: 0.1)
        case 2: return Color(white: 0.65)
        case 3: return Color(red: 0.75, green: 0.45, blue: 0.2)
        default: return Color(.tertiarySystemFill)
        }
    }

    private func difficultyColor(_ d: Difficulty) -> Color {
        switch d {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}

// MARK: - Data model for a racer entry
extension RouteStatsView {
    struct RacerEntry {
        let name: String
        let avatarSystemName: String
        let bestTime: TimeInterval
        let totalRaces: Int
        let avgSpeed: Double
        let lastRaced: Date
        let isYou: Bool
    }
}

#Preview {
    NavigationStack {
        RouteStatsView(route: SavedRoute(name: "Test Route", coordinates: []))
            .environmentObject(AppState())
    }
}
