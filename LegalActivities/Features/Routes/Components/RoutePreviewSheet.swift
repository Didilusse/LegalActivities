//
//  RoutePreviewSheet.swift
//  LegalActivities
//
//  Pre-race overview sheet: map, route stats, estimated time, created-by, leaderboard peek.
//  Presented when the user taps a route in StartRacingView.
//

import SwiftUI
import MapKit

struct RoutePreviewSheet: View {
    let route: SavedRoute
    let locationManager: LocationManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    /// Callback to actually start the race (pushes RaceInProgressView in the parent stack)
    var onStartRace: () -> Void

    private var units: UnitPreference { appState.userProfile.unitPreference }

    // Top-3 racers on this route for the leaderboard peek
    private struct PeekEntry: Identifiable {
        let id = UUID()
        let rank: Int
        let name: String
        let bestTime: TimeInterval
        let isYou: Bool
    }

    private var leaderboardPeek: [PeekEntry] {
        var entries: [PeekEntry] = []
        if let myBest = route.raceHistory.min(by: { $0.totalDuration < $1.totalDuration })?.totalDuration {
            entries.append(PeekEntry(rank: 0, name: appState.userProfile.name, bestTime: myBest, isYou: true))
        }
        for friend in appState.friends {
            let races = friend.recentRaces.filter { $0.routeId == route.id }
            if let best = races.min(by: { $0.totalDuration < $1.totalDuration })?.totalDuration {
                entries.append(PeekEntry(rank: 0, name: friend.name, bestTime: best, isYou: false))
            }
        }
        let sorted = entries.sorted { $0.bestTime < $1.bestTime }
        return sorted.prefix(3).enumerated().map { i, e in
            PeekEntry(rank: i + 1, name: e.name, bestTime: e.bestTime, isYou: e.isYou)
        }
    }

    @State private var showFullLeaderboard = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                mapSection
                infoSection
                    .padding(.top, 20)
                statsRow
                    .padding(.top, 16)
                if !route.tags.isEmpty {
                    tagsRow.padding(.top, 12)
                }
                createdBySection
                    .padding(.top, 20)
                if !leaderboardPeek.isEmpty {
                    leaderboardSection
                        .padding(.top, 20)
                }
                raceButton
                    .padding(.top, 24)
                    .padding(.bottom, 32)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(route.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    // MARK: - Map

    private var mapSection: some View {
        RouteOverviewMap(route: route)
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 0))  // flush top
            .overlay(alignment: .bottomLeading) {
                // Distance pill over the map
                Label(units.formatDistance(route.totalDistance), systemImage: "arrow.left.and.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(12)
            }
            .overlay(alignment: .bottomTrailing) {
                // Est. time pill over the map
                Label(estimatedTimeString, systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(12)
            }
    }

    // MARK: - Route Info Header

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                difficultyBadge
                if !route.raceHistory.isEmpty {
                    Text("\(route.raceHistory.count) race\(route.raceHistory.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                }
                Spacer()
                if let pb = appState.personalBest(for: route) {
                    Label(formatShortDuration(pb), systemImage: "trophy.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Stats Row (distance, est. time, checkpoints)

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(
                value: units.formatDistance(route.totalDistance),
                label: "Distance",
                icon: "arrow.left.and.right",
                color: .blue
            )
            Divider().frame(height: 40)
            statCell(
                value: estimatedTimeString,
                label: "Est. Time",
                icon: "clock.fill",
                color: .purple
            )
            Divider().frame(height: 40)
            let checkpoints = max(0, route.coordinates.count - 2)
            statCell(
                value: "\(checkpoints)",
                label: checkpoints == 1 ? "Checkpoint" : "Checkpoints",
                icon: "mappin.circle.fill",
                color: .orange
            )
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        .padding(.horizontal)
    }

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
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

    // MARK: - Tags

    private var tagsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(route.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Created By

    private var createdBySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Route Info")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                // Created by row
                HStack(spacing: 12) {
                    Image(systemName: appState.userProfile.avatarSystemName)
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .frame(width: 40, height: 40)
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
                .padding()

                Divider().padding(.horizontal)

                // Created date row
                HStack {
                    Label("Added on", systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(route.createdDate.formatted(date: .long, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .padding()
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            .padding(.horizontal)
        }
    }

    // MARK: - Leaderboard Peek

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Top Times")
                    .font(.headline)
                Spacer()
                Button {
                    showFullLeaderboard = true
                } label: {
                    Text("Full Leaderboard")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                .sheet(isPresented: $showFullLeaderboard) {
                    NavigationStack {
                        RouteStatsView(route: route)
                            .environmentObject(appState)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("Done") { showFullLeaderboard = false }
                                }
                            }
                    }
                }
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(leaderboardPeek.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(rankColor(entry.rank))
                                .frame(width: 26, height: 26)
                            Text("\(entry.rank)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(entry.rank <= 3 ? .white : .primary)
                        }
                        Text(entry.isYou ? (appState.userProfile.name.isEmpty ? "You" : appState.userProfile.name) : entry.name)
                            .font(.subheadline)
                            .fontWeight(entry.isYou ? .semibold : .regular)
                            .foregroundStyle(entry.isYou ? .blue : .primary)
                        if entry.isYou {
                            Text("You")
                                .font(.caption2).foregroundStyle(.blue)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        Spacer()
                        Text(formatShortDuration(entry.bestTime))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(entry.rank == 1 ? Color(red: 0.8, green: 0.65, blue: 0.1) : .primary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(entry.isYou ? Color.blue.opacity(0.04) : Color.clear)
                    if index < leaderboardPeek.count - 1 {
                        Divider().padding(.horizontal)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            .padding(.horizontal)
        }
    }

    // MARK: - Race Button

    private var raceButton: some View {
        Button {
            // The parent view will handle dismissing the sheet and navigation
            onStartRace()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "flag.checkered")
                    .font(.headline)
                Text("Race This Route")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.green)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.green.opacity(0.35), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private var estimatedTimeString: String {
        let t = route.estimatedDuration
        let m = Int(t) / 60
        if m < 60 { return "\(m) min" }
        let h = m / 60
        let rem = m % 60
        return rem == 0 ? "\(h) hr" : "\(h)h \(rem)m"
    }

    private var difficultyBadge: some View {
        Text(route.difficulty.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(difficultyColor(route.difficulty).opacity(0.15))
            .foregroundStyle(difficultyColor(route.difficulty))
            .clipShape(Capsule())
    }

    private func difficultyColor(_ d: Difficulty) -> Color {
        switch d {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 0.85, green: 0.73, blue: 0.1)
        case 2: return Color(white: 0.65)
        case 3: return Color(red: 0.75, green: 0.45, blue: 0.2)
        default: return Color(.tertiarySystemFill)
        }
    }
}
