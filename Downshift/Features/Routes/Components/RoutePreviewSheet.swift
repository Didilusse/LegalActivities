//
//  RoutePreviewSheet.swift
//  Downshift
//
//  Pre-race overview sheet: map, route stats, and race button.
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
    /// The Bool parameter indicates whether the route should be reversed
    var onStartRace: (Bool) -> Void
    
    /// Toggle for reversing the route direction
    @State private var reverseDirection = false
    @State private var showFullLeaderboard = false

    private var units: UnitPreference { appState.userProfile.unitPreference }
    
    // Personal best time for this route
    private var personalBest: TimeInterval? {
        appState.personalBest(for: route)
    }
    
    // Checkpoint count
    private var checkpointCount: Int {
        max(0, route.coordinates.count - 2)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Scrollable content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero map section
                    mapSection
                    
                    // Quick info bar
                    quickInfoBar
                        .padding(.top, 16)
                    
                    // Personal best card (if exists)
                    if personalBest != nil {
                        personalBestCard
                            .padding(.top, 12)
                    }
                    
                    // Route details section
                    routeDetailsSection
                        .padding(.top, 16)
                    
                    // Extra padding for the floating button
                    Color.clear.frame(height: 140)
                }
            }
            .background(Color(.systemGroupedBackground))
            
            // Floating race button at bottom
            floatingRaceButton
        }
        .navigationTitle(route.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !route.raceHistory.isEmpty {
                    Button {
                        showFullLeaderboard = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                    }
                }
            }
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

    // MARK: - Hero Map Section
    
    private var mapSection: some View {
        ZStack(alignment: .bottom) {
            RouteOverviewMap(route: route)
                .frame(height: 280)
            
            // Gradient overlay at bottom for readability
            LinearGradient(
                colors: [.clear, .black.opacity(0.4)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
            
            // Stats overlay on map
            HStack(spacing: 16) {
                // Distance
                statPill(
                    icon: "road.lanes",
                    value: units.formatDistance(route.totalDistance),
                    color: .blue
                )
                
                // Time
                statPill(
                    icon: "clock.fill",
                    value: estimatedTimeString,
                    color: .purple
                )
                
                // Checkpoints
                if checkpointCount > 0 {
                    statPill(
                        icon: "mappin.circle.fill",
                        value: "\(checkpointCount)",
                        color: .orange
                    )
                }
                
                Spacer()
                
                // Difficulty badge
                Text(route.difficulty.rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(difficultyColor(route.difficulty))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }
    
    private func statPill(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(value)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.9))
        .clipShape(Capsule())
    }
    
    // MARK: - Quick Info Bar
    
    private var quickInfoBar: some View {
        HStack(spacing: 12) {
            // Race count
            if !route.raceHistory.isEmpty {
                Label("\(route.raceHistory.count) race\(route.raceHistory.count == 1 ? "" : "s")", systemImage: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Location
            if let location = route.location, !location.isEmpty {
                Label(location, systemImage: "location.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Tags
            if !route.tags.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.caption2)
                    Text(route.tags.prefix(2).joined(separator: ", "))
                        .font(.caption)
                    if route.tags.count > 2 {
                        Text("+\(route.tags.count - 2)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Personal Best Card
    
    private var personalBestCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 44, height: 44)
                .background(Color.yellow.opacity(0.15))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Personal Best")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let pb = personalBest {
                    Text(formatDuration(pb))
                        .font(.title3.weight(.bold).monospacedDigit())
                }
            }
            
            Spacer()
            
            Button {
                showFullLeaderboard = true
            } label: {
                Text("View Stats")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }
    
    // MARK: - Route Details Section
    
    private var routeDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route Details")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                // Created by
                detailRow(
                    icon: "person.circle.fill",
                    iconColor: .blue,
                    title: "Created by",
                    value: appState.userProfile.name.isEmpty ? "You" : appState.userProfile.name
                )
                
                Divider().padding(.leading, 52)
                
                // Date added
                detailRow(
                    icon: "calendar",
                    iconColor: .green,
                    title: "Added",
                    value: route.createdDate.formatted(date: .abbreviated, time: .omitted)
                )
                
                if checkpointCount > 0 {
                    Divider().padding(.leading, 52)
                    
                    // Checkpoints detail
                    detailRow(
                        icon: "mappin.and.ellipse",
                        iconColor: .orange,
                        title: "Checkpoints",
                        value: "\(checkpointCount) waypoint\(checkpointCount == 1 ? "" : "s")"
                    )
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }
    
    private func detailRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 28)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    // MARK: - Floating Race Button
    
    private var floatingRaceButton: some View {
        VStack(spacing: 0) {
            // Subtle top border
            Rectangle()
                .fill(Color(.separator).opacity(0.3))
                .frame(height: 0.5)
            
            VStack(spacing: 12) {
                // Reverse toggle (compact)
                HStack(spacing: 10) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(reverseDirection ? .orange : .secondary)
                    
                    Text("Reverse Direction")
                        .font(.subheadline)
                        .foregroundStyle(reverseDirection ? .primary : .secondary)
                    
                    Spacer()
                    
                    Toggle("", isOn: $reverseDirection)
                        .labelsHidden()
                        .tint(.orange)
                }
                .padding(.horizontal, 4)
                
                // Race button
                Button {
                    onStartRace(reverseDirection)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "flag.checkered.2.crossed")
                            .font(.system(size: 18, weight: .semibold))
                        Text(reverseDirection ? "Start Race (Reversed)" : "Start Race")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: reverseDirection 
                                ? [Color.orange, Color.orange.opacity(0.8)]
                                : [Color.green, Color(red: 0.2, green: 0.7, blue: 0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(
                        color: (reverseDirection ? Color.orange : Color.green).opacity(0.4),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.regularMaterial)
        }
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
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins >= 60 {
            let hrs = mins / 60
            let remMins = mins % 60
            return String(format: "%d:%02d:%02d", hrs, remMins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }

    private func difficultyColor(_ d: Difficulty) -> Color {
        switch d {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}
