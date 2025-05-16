//
//  RaceViewModel.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/12/25.
//



import Foundation
import MapKit
import CoreLocation
import Combine
import SwiftUI

enum RaceState {
    case notStarted
    case inProgress
    case completed
}

class RaceViewModel: ObservableObject {
    let route: SavedRoute
    @ObservedObject var locationManager: LocationManager
    
    @Published var raceState: RaceState // Use your existing enum: .notStarted, .inProgress, .completed
    @Published var region: MKCoordinateRegion
    
    @Published var elapsedTime: TimeInterval = 0
    @Published var isUserInStartZone: Bool = false
    @Published var nextTargetMapCoordinate: CLLocationCoordinate2D?
    // Lap timing for segments (Start-CP1, CP1-CP2, etc.)
    @Published var lapSegmentDurations: [TimeInterval] = []
    @Published var nextCheckpointIndex: Int = 0 // Index in route.clCoordinates we are heading towards
    @Published var lastCompletedRaceResult: RaceResult? = nil
    // For display, derived from locationManager or calculated
    @Published var currentSpeed: Double = 0 // m/s, from locationManager
    @Published var distanceRaced: Double = 0 // meters, from locationManager
    @Published var remainingDistance: Double = 0 // meters
    
    private var timer: Timer?
    private var raceStartTime: Date?
    private var lastLapTimeMarker: TimeInterval = 0 // To calculate segment duration
    private var cancellables = Set<AnyCancellable>()
    
    private let startZoneIdentifier = "race_start" // Matches LocationManager
    private let finishZoneIdentifier = "race_finish"
    private func checkpointIdentifier(forIndex index: Int) -> String { "checkpoint_\(index)" }
    private let geofenceRadius: CLLocationDistance = 30.0 // meters, adjust as needed
    
    private var totalPlannedRouteDistance: Double = 0 // Pre-calculated distance of the saved route
    
    init(route: SavedRoute, locationManager: LocationManager) {
        self.route = route
        self.locationManager = locationManager
        self.raceState = .notStarted // Initialize from your enum
        
        if let startCoord = route.startCoordinate {
            self.region = MKCoordinateRegion(center: startCoord, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        } else {
            self.region = MKCoordinateRegion() // Default empty region
        }
        
        // Calculate total planned route distance
        self.totalPlannedRouteDistance = calculateTotalPlannedDistance(coordinates: route.clCoordinates)
        self.remainingDistance = self.totalPlannedRouteDistance
        
        // Subscribe to LocationManager updates
        locationManager.$isInStartRegion
            .receive(on: DispatchQueue.main)
            .assign(to: \.isUserInStartZone, on: self)
            .store(in: &cancellables)
        
        locationManager.regionEntrySubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enteredRegionIdentifier in
                self?.handleRegionEntry(identifier: enteredRegionIdentifier)
            }
            .store(in: &cancellables)
        
        // Subscribe to speed and distance from LocationManager for UI display
        locationManager.$speed
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentSpeed, on: self)
            .store(in: &cancellables)
        
        locationManager.$totalDistance // This is distance covered since locationManager.startTracking()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newDistanceRaced in
                guard let self = self else { return }
                self.distanceRaced = newDistanceRaced
                if self.raceState == .inProgress { // Only update remaining if race is on
                    self.remainingDistance = max(0, self.totalPlannedRouteDistance - newDistanceRaced)
                }
            }
            .store(in: &cancellables)
        
        setupInitialGeofences()
    }
    
    deinit {
        stopRaceCleanup()
    }
    
    private func calculateTotalPlannedDistance(coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count > 1 else { return 0 }
        var totalDistance: CLLocationDistance = 0 // Use CLLocationDistance for clarity
        for i in 0..<(coordinates.count - 1) {
            let loc1 = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let loc2 = CLLocation(latitude: coordinates[i+1].latitude, longitude: coordinates[i+1].longitude)
            totalDistance += loc1.distance(from: loc2)
        }
        print("RaceViewModel: Calculated total planned route distance: \(totalDistance)m")
        return totalDistance
    }
    
    private func setupInitialGeofences() {
        locationManager.requestLocationPermission()
        if let startCoord = route.startCoordinate {
            locationManager.setupGeofence(at: startCoord, radius: geofenceRadius, identifier: startZoneIdentifier)
        }
    }
    
    var formattedTime: String { formatTimeDisplay(elapsedTime) }
    var formattedDistanceRaced: String { String(format: "%.2f km", distanceRaced / 1000) }
    var formattedCurrentSpeed: String { String(format: "%.1f km/h", (currentSpeed * 3.6)) }
    var formattedRemainingDistance: String { String(format: "%.2f km", remainingDistance / 1000) }
    
    func formatTimeDisplay(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: seconds) ?? "00:00:00"
    }
    private func checkpointIdentifier(forTargetCoordIndex indexInRoute: Int) -> String {
        return "checkpoint_\(indexInRoute)"
    }
    func startRace() {
        guard isUserInStartZone else { print("VM: Cannot start. User not in start zone."); return }
        // Allow restarting a completed race if user is back in start zone
        guard raceState == .notStarted || raceState == .completed else {
            print("VM: Race already in progress or in an invalid state to start."); return
        }
        
        print("VM: Starting race for route '\(route.name)'!")
        // Reset all race-specific states
        raceState = .inProgress
        elapsedTime = 0
        lastLapTimeMarker = 0
        lapSegmentDurations.removeAll()
        
        // Start is coord[0]. First target is coord[1].
        nextCheckpointIndex = 1
        
        // Reset distance in LocationManager AND local copies
        locationManager.totalDistance = 0
        self.distanceRaced = 0
        self.remainingDistance = self.totalPlannedRouteDistance
        
        locationManager.startTracking(forRace: true) // This will reset LM's internal distance too
        
        raceStartTime = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let rStartTime = self.raceStartTime else { return }
            self.elapsedTime = Date().timeIntervalSince(rStartTime)
        }
        
        print("VM: Stopping monitoring for start zone: \(startZoneIdentifier)")
        locationManager.stopMonitoringGeofence(identifier: startZoneIdentifier)
        setupGeofenceForNextTarget()
    }
    
    private func setupGeofenceForNextTarget() {
        guard raceState == .inProgress else { // Don't set up if race isn't active
            print("VM: Race not in progress, not setting up next geofence.")
            return
        }
        guard nextCheckpointIndex < route.clCoordinates.count else {
            print("VM: All points processed. nextCheckpointIndex: \(nextCheckpointIndex). Race should have finished or is finishing.")
            // If this is hit and race is still .inProgress, it means finish wasn't properly identified.
            // However, handleRegionEntry should call completeRace if it's the finish.
            return
        }
        
        let targetCoordinate = route.clCoordinates[nextCheckpointIndex]
        let targetIdentifier: String
        
        if nextCheckpointIndex == route.clCoordinates.count - 1 {
            targetIdentifier = finishZoneIdentifier
            print("VM: Monitoring for FINISH LINE (\(targetIdentifier)) at index \(nextCheckpointIndex), Coord: \(targetCoordinate)")
        } else {
            targetIdentifier = checkpointIdentifier(forTargetCoordIndex: nextCheckpointIndex)
            print("VM: Monitoring for Checkpoint (\(targetIdentifier)) at index \(nextCheckpointIndex), Coord: \(targetCoordinate)")
        }
        locationManager.setupGeofence(at: targetCoordinate, radius: geofenceRadius, identifier: targetIdentifier)
    }
    
    private func handleRegionEntry(identifier: String) {
        guard raceState == .inProgress else {
            print("VM: Ignoring region entry (\(identifier)) because race is not in progress. State: \(raceState)")
            return
        }
        print("VM: Handling region entry for \(identifier). Current elapsedTime: \(elapsedTime), lastLapTimeMarker: \(lastLapTimeMarker)")
        
        // Stop monitoring the region we just entered
        locationManager.stopMonitoringGeofence(identifier: identifier)
        
        let currentSegmentDuration = elapsedTime - lastLapTimeMarker
        if currentSegmentDuration >= 0 { // Ensure non-negative segment time
            lapSegmentDurations.append(currentSegmentDuration)
        } else {
            lapSegmentDurations.append(0) // Should not happen
            print("VM WARNING: Negative segment duration detected for \(identifier)!")
        }
        lastLapTimeMarker = elapsedTime
        print("VM: Segment \(lapSegmentDurations.count) duration: \(formatTimeDisplay(currentSegmentDuration)) for \(identifier)")
        
        
        if identifier == finishZoneIdentifier {
            print("VM: Finish line (\(identifier)) entered. Calling completeRace().")
            completeRace() // This is the correct way to complete
        } else if identifier.starts(with: "checkpoint_") {
            let indexStr = identifier.replacingOccurrences(of: "checkpoint_", with: "")
            if let enteredCheckpointCoordIndex = Int(indexStr) {
                if enteredCheckpointCoordIndex == nextCheckpointIndex {
                    print("VM: Correct checkpoint \(identifier) entered.")
                    nextCheckpointIndex += 1
                    if nextCheckpointIndex < route.clCoordinates.count {
                        setupGeofenceForNextTarget()
                    } else {
                        // This means the checkpoint just entered was the one *before* the finish,
                        // but finish wasn't set up as the next target somehow.
                        // This should ideally not happen if setupGeofenceForNextTarget correctly identifies the finish.
                        print("VM Error: Reached end of coordinates after checkpoint. Expected finish geofence next. Forcing completion.")
                        completeRace()
                    }
                } else {
                    print("VM: Entered out-of-sequence/old checkpoint (\(identifier)). Expected target index: \(nextCheckpointIndex). Ignoring.")
                    // Do not advance or set up new geofence if it's an old one.
                    // Re-monitor this old one if it was a mistake to stop. Or just ignore.
                }
            }
        }
    }
    
    func completeRace() {
        guard raceState == .inProgress else { // Check if already completed or not started
            print("VM: completeRace() called but race not in progress. State: \(raceState)")
            return
        }
        
        let finalTotalDistance = locationManager.totalDistance // <<< Read distance BEFORE stopping tracking
        
        print("VM: Completing race. Stopping timer and tracking.")
        raceState = .completed // Set state first
        timer?.invalidate(); timer = nil
        locationManager.stopTracking()
        locationManager.stopAllGeofences()
        
        let finalAverageSpeed = elapsedTime > 0 && finalTotalDistance > 0 ? (finalTotalDistance / elapsedTime) : 0
        
        print("VM.completeRace() STATS:")
        print("  - Elapsed Time: \(formatTimeDisplay(elapsedTime)) (\(elapsedTime)s)")
        print("  - Final Total Distance (from LM): \(finalTotalDistance)m")
        print("  - Calculated Average Speed: \(finalAverageSpeed) m/s (\(finalAverageSpeed * 3.6) km/h)")
        print("  - Lap Segment Durations: \(lapSegmentDurations.map { formatTimeDisplay($0) })")
        
        let result = RaceResult(
            date: Date(),
            totalDuration: elapsedTime,
            lapDurations: lapSegmentDurations,
            totalDistance: finalTotalDistance,
            averageSpeed: finalAverageSpeed
        )
        
        self.lastCompletedRaceResult = result // For the sheet
        persistRaceResult(result, forRoute: route.id)
    }
    
    private func persistRaceResult(_ newResult: RaceResult, forRoute routeID: UUID) {
        var allSavedRoutes: [SavedRoute] = []
        if let data = UserDefaults.standard.data(forKey: savedRoutesUserDefaultsKey) {
            do {
                allSavedRoutes = try JSONDecoder().decode([SavedRoute].self, from: data)
            } catch {
                print("Error decoding routes for saving result: \(error)")
                // Decide recovery strategy: overwrite with new if data is corrupt? Or fail?
            }
        }
        
        if let routeIndex = allSavedRoutes.firstIndex(where: { $0.id == routeID }) {
            allSavedRoutes[routeIndex].raceHistory.append(newResult)
            // Optionally sort raceHistory by date if desired
            allSavedRoutes[routeIndex].raceHistory.sort { $0.date > $1.date }
            
            do {
                let data = try JSONEncoder().encode(allSavedRoutes)
                UserDefaults.standard.set(data, forKey: savedRoutesUserDefaultsKey)
                print("Race result saved and routes updated in UserDefaults.")
            } catch {
                print("Error encoding routes after adding race result: \(error)")
            }
        } else {
            print("Error: Could not find route with ID \(routeID) to save race result.")
        }
    }
    
    func stopRaceCleanup() {
        timer?.invalidate()
        timer = nil
        // Don't stop locationManager's general tracking here unless it was only for this race
        // locationManager.stopTracking()
        locationManager.stopAllGeofences() // Specifically stop race geofences
    }
}
