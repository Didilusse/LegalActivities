//
//  RaceInProgressView.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/16/25.
//

import SwiftUI
import MapKit

struct RaceInProgressView: View {
    @StateObject var vm: RaceViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var raceMapViewInstance = MKMapView()
    
    init(route: SavedRoute, locationManager: LocationManager) {
        _vm = StateObject(wrappedValue: RaceViewModel(route: route, locationManager: locationManager))
    }
    
    var body: some View {
        VStack(spacing: 10) { // Reduced main spacing
            Text(vm.route.name)
                .font(.largeTitle.weight(.bold))
                .padding(.top)
            
            // Map Display (Placeholder - use your DetailMapView or SwiftUI Map)
            RaceLiveMapViewBridge(
                mapView: $raceMapViewInstance,
                region: $vm.region, // ViewModel can still manage an overall region if needed
                routeToDisplay: vm.route,
                nextTargetCoordinate: vm.nextTargetMapCoordinate, // Pass the next target
                currentRaceState: vm.raceState
            )
            .frame(height: 300) // Or dynamic
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            
            Button {
                raceMapViewInstance.setUserTrackingMode(.followWithHeading, animated: true)
            } label: {
                Image(systemName: "location.north.line.fill")
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding()
            Text(vm.formattedTime) // Total elapsed time
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .padding(.vertical, 5)
            
            HStack(spacing: 10) {
                InfoCard(title: "SPEED", value: vm.formattedCurrentSpeed)
                InfoCard(title: "DISTANCE", value: vm.formattedDistanceRaced)
                InfoCard(title: "REMAINING", value: vm.formattedRemainingDistance)
            }
            .padding(.horizontal)
            
            if vm.raceState == .notStarted || vm.raceState == .completed {
                Text(vm.isUserInStartZone ? "You are in the start zone!" : "Proceed to the start zone.")
                    .foregroundColor(vm.isUserInStartZone ? .green : .orange)
                    .padding(.bottom, 5)
            }
            
            if vm.raceState == .inProgress,
               vm.nextCheckpointIndex < vm.route.clCoordinates.count {
                
                let targetLabel: String = {
                    if vm.nextCheckpointIndex == 0 {
                        return "Start"
                    } else if vm.nextCheckpointIndex == vm.route.clCoordinates.count - 1 {
                        return "Finish Line"
                    } else {
                        return "Checkpoint \(vm.nextCheckpointIndex)"
                    }
                }()
                
                Text("Next: \(targetLabel)")
                    .font(.headline)
                    .padding(.bottom, 5)
            }
            HStack(spacing: 20) {
                // ... (Button logic as before, using vm.raceState and vm.isUserInStartZone) ...
                if vm.raceState == .notStarted || vm.raceState == .completed {
                    Button("Start Race") { vm.startRace() }
                        .disabled(!vm.isUserInStartZone)
                        .buttonStyle(PrimaryRaceButton(color: vm.isUserInStartZone ? .green : .gray))
                } else if vm.raceState == .inProgress {
                    Button("Finish Race Manually") { vm.completeRace() } // Or "Stop"
                        .buttonStyle(PrimaryRaceButton(color: .red))
                }
            }
            .padding(.bottom, 10)
            
            // Display Lap/Segment Times
            if !vm.lapSegmentDurations.isEmpty {
                Text("Segment Times").font(.headline).padding(.top)
                List {
                    ForEach(vm.lapSegmentDurations.indices, id: \.self) { index in
                        HStack {
                            // Determine if it's a checkpoint or finish for labeling
                            let segmentLabel = (index + 1) < (vm.route.clCoordinates.count - 1) ? "To CP \(index + 1)" : "To Finish"
                            Text("Segment \(index + 1) (\(segmentLabel)):")
                            Spacer()
                            Text(vm.formatTimeDisplay(vm.lapSegmentDurations[index]))
                        }
                    }
                }
                .listStyle(.plain)
            }
            Spacer()
        }
        .navigationTitle("Race View")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.locationManager.requestLocationPermission() }
        .onDisappear { vm.stopRaceCleanup() }
        .sheet(item: $vm.lastCompletedRaceResult, onDismiss: {
            // This onDismiss is called when the sheet is dismissed by any means
            // You might want to reset race state or dismiss RaceInProgressView here
            print("RaceFinishedView dismissed. Current raceState: \(vm.raceState)")
            if vm.raceState == .completed { // Use your RaceState enum
                // vm.raceState = .notStarted // Reset for another race of same route, or
                dismiss() // Dismiss RaceInProgressView to go back to RouteDetailView/RoutesListView
            }
        }) { result in
            // This content closure is called when vm.lastCompletedRaceResult is NOT nil
            RaceFinishedView(raceResult: result, routeName: vm.route.name)
        }
    }
    
    // Helper InfoCard for displaying speed, distance etc.
    struct InfoCard: View {
        let title: String
        let value: String
        
        var body: some View {
            VStack {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.gray)
                Text(value)
                    .font(.title3.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.thinMaterial)
            .cornerRadius(8)
        }
    }
    
    // PrimaryRaceButton Style (as defined before)
    struct PrimaryRaceButton: ButtonStyle {
        var color: Color = .blue
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline)
                .padding()
                .frame(minWidth: 120, minHeight: 44)
                .background(configuration.isPressed ? color.opacity(0.8) : color)
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(radius: 2)
        }
    }
    
}
