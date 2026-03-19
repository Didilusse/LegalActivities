//
//  RaceResultDetailView.swift
//  Downshift
//
//  Detailed stats for a single race result: performance metrics, split segments,
//  comparison to personal best, worldwide leaderboard, and friends ranking.
//

import SwiftUI

struct RaceResultDetailView: View {
    let result: RaceResult
    let route: SavedRoute
    @EnvironmentObject var appState: AppState

    private var units: UnitPreference { appState.userProfile.unitPreference }

    // All racers on this route sorted by best time (same logic as RouteStatsView)
    private struct LeaderEntry: Identifiable {
        let id = UUID()
        let name: String
        let avatarSystemName: String
        let bestTime: TimeInterval
        let isYou: Bool
        let isFriend: Bool
    }

    private var leaderboard: [LeaderEntry] {
        var entries: [LeaderEntry] = []
        let myBest = route.raceHistory.min(by: { $0.totalDuration < $1.totalDuration })?.totalDuration
        if let best = myBest {
            entries.append(LeaderEntry(
                name: appState.userProfile.name,
                avatarSystemName: appState.userProfile.avatarSystemName,
                bestTime: best,
                isYou: true,
                isFriend: false
            ))
        }
        for friend in appState.friends {
            let races = friend.recentRaces.filter { $0.routeId == route.id }
            if let best = races.min(by: { $0.totalDuration < $1.totalDuration })?.totalDuration {
                entries.append(LeaderEntry(
                    name: friend.name,
                    avatarSystemName: friend.avatarSystemName,
                    bestTime: best,
                    isYou: false,
                    isFriend: true
                ))
            }
        }
        return entries.sorted { $0.bestTime < $1.bestTime }
    }

    private var friendLeaderboard: [LeaderEntry] {
        leaderboard.filter { $0.isFriend || $0.isYou }
    }

    private var yourRank: Int? {
        leaderboard.firstIndex(where: { $0.isYou }).map { $0 + 1 }
    }

    private var yourFriendRank: Int? {
        friendLeaderboard.firstIndex(where: { $0.isYou }).map { $0 + 1 }
    }

    private var personalBest: TimeInterval? {
        route.raceHistory.min(by: { $0.totalDuration < $1.totalDuration })?.totalDuration
    }

    private var isPersonalBest: Bool {
        guard let pb = personalBest else { return true }
        return result.totalDuration <= pb
    }

    private var deltaFromPB: TimeInterval? {
        guard let pb = personalBest, !isPersonalBest else { return nil }
        return result.totalDuration - pb
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                heroBanner
                metricsGrid
                if !result.lapDurations.isEmpty {
                    splitsSection
                }
                pbComparisonCard
                leaderboardSection
                friendsSection
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Race Result")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        VStack(spacing: 0) {
            // Coloured top strip
            LinearGradient(
                colors: isPersonalBest
                    ? [Color(red: 0.1, green: 0.5, blue: 0.2), Color(red: 0.2, green: 0.7, blue: 0.3)]
                    : [Color(red: 0.1, green: 0.2, blue: 0.5), Color(red: 0.2, green: 0.35, blue: 0.65)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .overlay {
                VStack(spacing: 10) {
                    // PB badge or date
                    if isPersonalBest {
                        Label("New Personal Best!", systemImage: "trophy.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.yellow)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    } else {
                        Text(result.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    // Big time display
                    Text(formatDuration(result.totalDuration))
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Text(route.name)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)

                    // Delta from PB
                    if let delta = deltaFromPB {
                        Text("+" + formatShortDuration(delta) + " from PB")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.vertical, 24)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
        }
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Performance", icon: "bolt.fill", color: .blue)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricTile(
                    value: units.formatDistance(result.totalDistance),
                    label: "Distance",
                    icon: "arrow.left.and.right",
                    color: .blue
                )
                metricTile(
                    value: units.formatSpeed(result.averageSpeed),
                    label: "Avg Speed",
                    icon: "speedometer",
                    color: .orange
                )
                metricTile(
                    value: formatShortDuration(result.totalDuration),
                    label: "Finish Time",
                    icon: "clock.fill",
                    color: .purple
                )
                if let pb = personalBest {
                    metricTile(
                        value: formatShortDuration(pb),
                        label: "Personal Best",
                        icon: "trophy.fill",
                        color: .yellow
                    )
                }
                if let rank = yourRank {
                    metricTile(
                        value: "#\(rank) of \(leaderboard.count)",
                        label: "World Rank",
                        icon: "globe",
                        color: .teal
                    )
                }
                if let rank = yourFriendRank, friendLeaderboard.count > 1 {
                    metricTile(
                        value: "#\(rank) of \(friendLeaderboard.count)",
                        label: "Friend Rank",
                        icon: "person.2.fill",
                        color: .green
                    )
                }
            }
        }
        .padding(.horizontal)
    }

    private func metricTile(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    // MARK: - Splits Section

    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Segment Splits", icon: "flag.fill", color: .orange)

            VStack(spacing: 0) {
                ForEach(result.lapDurations.indices, id: \.self) { i in
                    splitRow(index: i, duration: result.lapDurations[i])
                    if i < result.lapDurations.count - 1 {
                        Divider().padding(.horizontal)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        .padding(.horizontal)
    }

    private func splitRow(index: Int, duration: TimeInterval) -> some View {
        let isLast = index == result.lapDurations.count - 1
        let label = isLast ? "Finish" : "Checkpoint \(index + 1)"
        let icon = isLast ? "flag.checkered" : "mappin.circle.fill"
        let iconColor: Color = isLast ? .green : .orange

        // Fastest / slowest split highlight
        let fastest = result.lapDurations.min() ?? 0
        let slowest = result.lapDurations.max() ?? 0
        let isFastest = duration == fastest && result.lapDurations.count > 1
        let isSlowest = duration == slowest && result.lapDurations.count > 1

        return HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Segment \(index + 1) → \(label)")
                    .font(.subheadline).fontWeight(.medium)
                if isFastest {
                    Text("Fastest split")
                        .font(.caption2).foregroundStyle(.green)
                } else if isSlowest {
                    Text("Slowest split")
                        .font(.caption2).foregroundStyle(.red)
                }
            }

            Spacer()

            Text(formatShortDuration(duration))
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(isFastest ? .green : isSlowest ? .red : .primary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - PB Comparison Card

    private var pbComparisonCard: some View {
        let pb = personalBest ?? result.totalDuration
        let thisTime = result.totalDuration
        let ratio = thisTime / pb  // 1.0 = matched PB, >1.0 = slower

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("vs. Personal Best", icon: "trophy.fill", color: .yellow)

            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("This Race")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(formatDuration(thisTime))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Personal Best")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(formatDuration(pb))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.yellow)
                    }
                }

                // Progress bar: PB is baseline, this race position shown relative
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.tertiarySystemFill))
                            .frame(height: 10)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isPersonalBest ? Color.green : Color.blue)
                            .frame(width: min(geo.size.width / ratio, geo.size.width), height: 10)
                    }
                }
                .frame(height: 10)

                if isPersonalBest {
                    Label("You set a new personal best!", systemImage: "star.fill")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.green)
                } else if let delta = deltaFromPB {
                    Text("You were \(formatShortDuration(delta)) slower than your best")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        .padding(.horizontal)
    }

    // MARK: - World Leaderboard

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Leaderboard", icon: "globe", color: .teal)

            if leaderboard.isEmpty {
                emptyCard("No other racers yet")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, entry in
                        leaderboardRow(rank: index + 1, entry: entry, highlightCurrent: entry.isYou && result.totalDuration == entry.bestTime)
                        if index < leaderboard.count - 1 {
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Friends Section

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Friends", icon: "person.2.fill", color: .green)

            if friendLeaderboard.count <= 1 {
                emptyCard("Add friends to compare times")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(friendLeaderboard.enumerated()), id: \.element.id) { index, entry in
                        leaderboardRow(rank: index + 1, entry: entry, highlightCurrent: entry.isYou && result.totalDuration == entry.bestTime)
                        if index < friendLeaderboard.count - 1 {
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Shared Row

    private func leaderboardRow(rank: Int, entry: LeaderEntry, highlightCurrent: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(rankColor(rank))
                    .frame(width: 28, height: 28)
                Text("\(rank)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(rank <= 3 ? .white : .primary)
            }

            Image(systemName: entry.avatarSystemName)
                .font(.title2)
                .foregroundStyle(entry.isYou ? .blue : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.isYou ? appState.userProfile.name : entry.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(entry.isYou ? .blue : .primary)
                    if entry.isYou {
                        Text("You")
                            .font(.caption2).foregroundStyle(.blue)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                if highlightCurrent {
                    Text("← this race")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatShortDuration(entry.bestTime))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(rank == 1 ? Color(red: 0.8, green: 0.65, blue: 0.1) : .primary)
                Text("best")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(entry.isYou ? Color.blue.opacity(0.04) : Color.clear)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(title).font(.headline)
        }
    }

    private func emptyCard(_ message: String) -> some View {
        Text(message)
            .font(.subheadline).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 0.85, green: 0.73, blue: 0.1)
        case 2: return Color(white: 0.65)
        case 3: return Color(red: 0.75, green: 0.45, blue: 0.2)
        default: return Color(.tertiarySystemFill)
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    NavigationStack {
        RaceResultDetailView(
            result: RaceResult(
                totalDuration: 312,
                lapDurations: [95, 110, 107],
                totalDistance: 2400,
                averageSpeed: 7.7
            ),
            route: SavedRoute(name: "City Loop", coordinates: [])
        )
        .environmentObject(AppState())
    }
}
