//
//  RaceInProgressView.swift
//  LegalActivities
//

import SwiftUI
import MapKit

struct RaceInProgressView: View {
    @StateObject var vm: RaceViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState

    @State private var raceMapViewInstance = MKMapView()
    @State private var rallyMode: Bool

    init(route: SavedRoute, locationManager: LocationManager, units: UnitPreference) {
        _vm = StateObject(wrappedValue: RaceViewModel(route: route, locationManager: locationManager, units: units))
        // Read saved preference from UserDefaults at init time (appState not yet available)
        if let data = UserDefaults.standard.data(forKey: "userProfileData"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            _rallyMode = State(initialValue: profile.rallyDirectionsEnabled)
        } else {
            _rallyMode = State(initialValue: false)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Map (takes up half the screen) ──────────────────────────
                mapSection

                // ── Direction banner ────────────────────────────────────────
                directionBanner
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                // ── Metrics row ─────────────────────────────────────────────
                metricsRow
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                // ── Segment times (only while racing) ───────────────────────
                if !vm.lapSegmentDurations.isEmpty {
                    segmentTimesSection
                        .padding(.top, 8)
                }

                // ── Control buttons ─────────────────────────────────────────
                controlButtons
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
        }
        .navigationTitle(vm.route.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                rallyToggleButton
            }
        }
        .onAppear {
            vm.locationManager.requestLocationPermission()
            // Sync rally mode from live appState
            rallyMode = appState.userProfile.rallyDirectionsEnabled
        }
        .onDisappear { vm.stopRaceCleanup() }
        .sheet(item: $vm.lastCompletedRaceResult, onDismiss: {
            if vm.raceState == .completed { dismiss() }
        }) { result in
            RaceFinishedView(raceResult: result, routeName: vm.route.name, route: vm.route)
                .environmentObject(appState)
        }
    }

    // MARK: - Map Section

    private var mapSection: some View {
        ZStack(alignment: .bottomTrailing) {
            RaceLiveMapViewBridge(
                mapView: $raceMapViewInstance,
                region: $vm.region,
                routeToDisplay: vm.route,
                nextTargetCoordinate: vm.nextTargetMapCoordinate,
                currentRaceState: vm.raceState,
                roadPolylines: vm.roadPolylines
            )
            .ignoresSafeArea(edges: .top)

            // Re-center button
            Button {
                raceMapViewInstance.setUserTrackingMode(.followWithHeading, animated: true)
            } label: {
                Image(systemName: "location.north.line.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .background(.regularMaterial, in: Circle())
                    .shadow(radius: 3)
            }
            .padding(12)

            // Timer overlay (top-left of map)
            VStack {
                HStack {
                    Text(vm.formattedTime)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                    Spacer()
                }
                .padding(12)
                Spacer()
            }
        }
        .frame(height: UIScreen.main.bounds.height * 0.38)
    }

    // MARK: - Direction Banner

    @ViewBuilder
    private var directionBanner: some View {
        if vm.raceState == .notStarted || vm.raceState == .completed {
            // Pre-race: show "go to start zone" message
            HStack(spacing: 14) {
                Image(systemName: vm.isUserInStartZone ? "checkmark.circle.fill" : "location.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(vm.isUserInStartZone ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.isUserInStartZone ? "In Start Zone" : "Proceed to Start")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(vm.isUserInStartZone ? "Tap Start Race when ready" : "Head to the green start pin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(vm.isUserInStartZone ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(vm.isUserInStartZone ? Color.green.opacity(0.4) : Color.orange.opacity(0.4), lineWidth: 1)
                    )
            )
        } else if let instr = vm.currentInstruction {
            VStack(spacing: 6) {
                // Current instruction (large)
                currentInstructionCard(instr)
                // Next instruction (smaller preview)
                if let next = vm.nextInstruction {
                    nextInstructionRow(next)
                }
            }
        }
    }

    private func currentInstructionCard(_ instr: TurnInstruction) -> some View {
        if rallyMode {
            return AnyView(rallyInstructionCard(instr))
        } else {
            return AnyView(standardInstructionCard(instr))
        }
    }

    private func standardInstructionCard(_ instr: TurnInstruction) -> some View {
        HStack(spacing: 16) {
            Image(systemName: instr.direction.systemImage)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(directionColor(instr.direction))
                .frame(width: 64)

            VStack(alignment: .leading, spacing: 3) {
                // Direction label with live distance
                Group {
                    if instr.direction == .finish {
                        Text("Finish Line")
                    } else if instr.direction == .straight {
                        Text("Continue · \(liveDistanceText)")
                    } else {
                        Text("\(instr.direction.rawValue) in \(liveDistanceText)")
                    }
                }
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

                if instr.direction == .finish {
                    Text("You've almost made it!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if instr.direction != .straight {
                    Text(checkpointLabel(instr))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        )
    }

    private func rallyInstructionCard(_ instr: TurnInstruction) -> some View {
        let sev = instr.rallySeverity
        let isLeft = instr.rallyIsLeft
        let color = sev.map { severityColor($0) } ?? Color.blue

        return HStack(spacing: 0) {
            // LEFT column: live distance
            VStack(spacing: 2) {
                Text(instr.direction == .finish ? "FINISH" : liveDistanceText)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80)
            .padding(.vertical, 14)

            Divider()
                .frame(height: 56)
                .background(color.opacity(0.4))

            // RIGHT column: severity number + direction label + arrow
            HStack(spacing: 10) {
                if instr.direction == .finish {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 44, weight: .black))
                        .foregroundStyle(color)
                } else if let s = sev, let left = isLeft {
                    // Large severity number
                    Text("\(s)")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(color)
                        .frame(minWidth: 44)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(left ? "LEFT" : "RIGHT")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(color)
                        Image(systemName: left ? "arrow.turn.up.left" : "arrow.turn.up.right")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(color)
                    }
                } else {
                    // Flat / straight
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(color)
                        Text("FLAT")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(color)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(color.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: color.opacity(0.15), radius: 6, x: 0, y: 2)
        )
    }

    private func nextInstructionRow(_ instr: TurnInstruction) -> some View {
        HStack(spacing: 10) {
            Text("THEN")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(.tertiarySystemBackground), in: Capsule())

            if rallyMode, let sev = instr.rallySeverity {
                // Severity circle badge
                Text("\(sev)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(severityColor(sev), in: Circle())

                Image(systemName: instr.direction.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(severityColor(sev))

                Text("\(instr.rallyNoteText) · \(instr.rallyDistanceText(units: vm.units))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            } else if rallyMode {
                // Flat next note
                Image(systemName: instr.direction.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("\(instr.rallyNoteText) · \(instr.rallyDistanceText(units: vm.units))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
            } else {
                Image(systemName: instr.direction.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(directionColor(instr.direction))
                Text(instr.shortText(units: vm.units))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Metrics Row

    private var metricsRow: some View {
        HStack(spacing: 8) {
            MetricTile(label: "SPEED",     value: vm.formattedCurrentSpeed,   icon: "speedometer",        color: .blue)
            MetricTile(label: "DONE",      value: vm.formattedDistanceRaced,   icon: "arrow.left.and.right", color: .green)
            MetricTile(label: "LEFT",      value: vm.formattedRemainingDistance, icon: "flag.checkered",   color: .orange)
        }
    }

    // MARK: - Segment Times

    private var segmentTimesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Segment Times")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.lapSegmentDurations.indices, id: \.self) { i in
                        VStack(spacing: 2) {
                            Text(i < vm.route.clCoordinates.count - 2 ? "S\(i+1)→CP\(i+1)" : "S\(i+1)→Fin")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(vm.formatTimeDisplay(vm.lapSegmentDurations[i]))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Control Buttons

    @ViewBuilder
    private var controlButtons: some View {
        if vm.raceState == .notStarted || vm.raceState == .completed {
            Button {
                vm.startRace()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "flag.fill")
                        .font(.headline)
                    Text("Start Race")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    vm.isUserInStartZone ? Color.green : Color.gray.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 14)
                )
            }
            .disabled(!vm.isUserInStartZone)
        } else if vm.raceState == .inProgress {
            Button {
                vm.completeRace()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.headline)
                    Text("End Race")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Rally Toggle

    private var rallyToggleButton: some View {
        Button {
            rallyMode.toggle()
            appState.userProfile.rallyDirectionsEnabled = rallyMode
            appState.saveProfile()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: rallyMode ? "flag.2.crossed.fill" : "flag.2.crossed")
                    .font(.system(size: 13, weight: .semibold))
                Text(rallyMode ? "Rally" : "Rally")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(rallyMode ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(rallyMode ? Color.orange : Color(.secondarySystemBackground), in: Capsule())
        }
    }

    // MARK: - Helpers

    /// Live formatted distance to the current instruction's waypoint.
    /// Falls back to "–" if the race hasn't started yet or GPS is unavailable.
    private var liveDistanceText: String {
        guard let meters = vm.distanceToNextWaypoint else { return "–" }
        return vm.units == .metric
            ? (meters >= 1000
                ? String(format: "%.1f km", meters / 1000)
                : "\(Int(meters.rounded())) m")
            : (meters * 3.28084 >= 5280
                ? String(format: "%.1f mi", meters * 3.28084 / 5280)
                : "\(Int((meters * 3.28084).rounded())) ft")
    }

    private func checkpointLabel(_ instr: TurnInstruction) -> String {
        let idx = instr.waypointIndex
        let total = vm.route.clCoordinates.count
        if idx == 0 { return "Start" }
        if idx == total - 1 { return "Finish" }
        return "Checkpoint \(idx)"
    }

    private func directionColor(_ dir: TurnDirection) -> Color {
        switch dir {
        case .straight:                          return .blue
        case .slightLeft, .left, .sharpLeft:     return .cyan
        case .hairpinLeft:                       return .purple
        case .slightRight, .right, .sharpRight:  return .orange
        case .hairpinRight:                      return .red
        case .finish:                            return .green
        }
    }

    private func severityColor(_ sev: Int) -> Color {
        switch sev {
        case 1: return .red
        case 2: return .orange
        case 3: return Color(red: 0.9, green: 0.6, blue: 0)
        case 4: return .yellow
        case 5: return .green
        default: return .blue
        }
    }
}

// MARK: - MetricTile

private struct MetricTile: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

