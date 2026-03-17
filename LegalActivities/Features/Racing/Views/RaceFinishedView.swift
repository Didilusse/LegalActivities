//
//  RaceFinishedView.swift
//  LegalActivities
//
//  Post-race summary sheet. Shows headline stats and a button to open
//  the full RaceResultDetailView with leaderboards and splits.
//

import SwiftUI

struct RaceFinishedView: View {
    let raceResult: RaceResult
    let routeName: String
    /// The full SavedRoute — needed so RaceResultDetailView can build the leaderboard.
    /// Optional for backwards-compatibility; if nil the deep-dive button is hidden.
    var route: SavedRoute? = nil

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    finishHeader
                    quickStatsGrid
                    if !raceResult.lapDurations.isEmpty {
                        segmentTimesCard
                    }
                    actionButtons
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Race Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Finish Header

    private var finishHeader: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.4, blue: 0.2), Color(red: 0.15, green: 0.6, blue: 0.3)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 10) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                Text("Race Finished!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text(routeName)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                Text(formatDuration(raceResult.totalDuration))
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.top, 4)
            }
            .padding(.vertical, 30)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quick Stats Grid

    private var quickStatsGrid: some View {
        let units = appState.userProfile.unitPreference
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statTile(
                value: units.formatDistance(raceResult.totalDistance),
                label: "Distance",
                icon: "arrow.left.and.right",
                color: .blue
            )
            statTile(
                value: units.formatSpeed(raceResult.averageSpeed),
                label: "Avg Speed",
                icon: "speedometer",
                color: .orange
            )
            if let routeObj = route, let pb = appState.personalBest(for: routeObj) {
                statTile(
                    value: formatShortDuration(pb),
                    label: "Your PB",
                    icon: "trophy.fill",
                    color: .yellow
                )
                let delta = raceResult.totalDuration - pb
                statTile(
                    value: delta <= 0 ? "New PB!" : "+" + formatShortDuration(delta),
                    label: "vs. PB",
                    icon: delta <= 0 ? "star.fill" : "arrow.up",
                    color: delta <= 0 ? .green : .red
                )
            }
        }
        .padding(.horizontal)
    }

    private func statTile(value: String, label: String, icon: String, color: Color) -> some View {
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
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    // MARK: - Segment Times Card

    private var segmentTimesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "flag.fill").foregroundStyle(.orange)
                Text("Segment Splits").font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(raceResult.lapDurations.indices, id: \.self) { i in
                    let isLast = i == raceResult.lapDurations.count - 1
                    HStack {
                        Image(systemName: isLast ? "flag.checkered" : "mappin.circle.fill")
                            .foregroundStyle(isLast ? .green : .orange)
                            .frame(width: 20)
                        Text(isLast ? "Segment \(i + 1) → Finish" : "Segment \(i + 1) → CP\(i + 1)")
                            .font(.subheadline)
                        Spacer()
                        Text(formatShortDuration(raceResult.lapDurations[i]))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 11)
                    if i < raceResult.lapDurations.count - 1 {
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

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if let routeObj = route {
                NavigationLink {
                    RaceResultDetailView(result: raceResult, route: routeObj)
                        .environmentObject(appState)
                } label: {
                    Label("View Full Stats & Leaderboard", systemImage: "chart.bar.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

struct StatisticRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label).font(.headline)
                Spacer()
                Text(value).font(.body).monospacedDigit()
            }
            Divider()
        }
    }
}

#Preview {
    RaceFinishedView(
        raceResult: RaceResult(
            totalDuration: 312,
            lapDurations: [95, 110, 107],
            totalDistance: 2400,
            averageSpeed: 7.7
        ),
        routeName: "City Park Loop",
        route: SavedRoute(name: "City Park Loop", coordinates: [])
    )
    .environmentObject(AppState())
}
