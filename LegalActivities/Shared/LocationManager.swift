//
//  LocationManager.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/12/25.
//
import CoreLocation
import Foundation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var speed: Double = 0 // m/s
    @Published var totalDistance: Double = 0 // meters
    @Published var currentHeading: CLHeading? // For map orientation
    
    @Published var isInStartRegion: Bool = false
    let regionEntrySubject = PassthroughSubject<String, Never>()
    
    private let speedFilter = KalmanFilter() // Assuming KalmanFilter is defined
    private let coordFilter = KalmanFilter(q: 0.01, r: 10)
    private var previousLocation: CLLocation?
    private var monitoredRegionIdentifiers: Set<String> = []
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // Good for racing
        manager.activityType = .fitness
        // manager.distanceFilter = 10 // We'll set this dynamically or keep it low
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }
    
    func requestLocationPermission() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }
    
    func requestLocation() {
        manager.requestLocation() // For a one-time location update
    }
    func startTracking(forRace: Bool = false) {
            if CLLocationManager.locationServicesEnabled() {
                guard manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways else {
                    print("LocationManager: Cannot start tracking. Not authorized.")
                    if manager.authorizationStatus == .notDetermined {
                        manager.requestWhenInUseAuthorization()
                    }
                    return
                }
                
                print("LocationManager: Starting tracking (forRace: \(forRace)).")
                if forRace {
                    manager.distanceFilter = kCLDistanceFilterNone // More frequent updates for racing
                    manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation // Ensure best accuracy
                    print("LocationManager: Distance filter set to None for race.")
                } else {
                    manager.distanceFilter = 10 // Default for general tracking
                }
                
                // CRITICAL RESETS
                previousLocation = nil
                totalDistance = 0
                // If your KalmanFilters have state, reset them too:
                // speedFilter.reset()
                // coordFilter.reset()
                
                manager.startUpdatingLocation()
                manager.startUpdatingHeading() // For map orientation
                print("LocationManager: Tracking started. totalDistance and previousLocation reset.")
            } else {
                print("Location services are not enabled.")
            }
        }
        
        func stopTracking() {
            manager.stopUpdatingLocation()
            manager.stopUpdatingHeading()
            print("LocationManager: Location tracking stopped. final totalDistance: \(totalDistance)")
            // DO NOT reset totalDistance or previousLocation here. ViewModel reads it first.
        }
    
        func setupGeofence(at coordinate: CLLocationCoordinate2D, radius: CLLocationDistance = 30, identifier: String) { // Reduced default radius
            // ... (as before, ensure radius is appropriate) ...
            guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
                print("Geofencing not available."); return
            }
            stopMonitoringGeofence(identifier: identifier) // Remove old one first
            let geofenceRegion = CLCircularRegion(center: coordinate, radius: radius, identifier: identifier)
            geofenceRegion.notifyOnEntry = true; geofenceRegion.notifyOnExit = true
            manager.startMonitoring(for: geofenceRegion)
            monitoredRegionIdentifiers.insert(identifier)
            manager.requestState(for: geofenceRegion)
            print("LM: Monitoring for \(identifier) at \(coordinate), r:\(radius)m")
        }
    func stopMonitoringGeofence(identifier: String) {
        for region in manager.monitoredRegions {
            if region.identifier == identifier {
                manager.stopMonitoring(for: region)
                monitoredRegionIdentifiers.remove(identifier)
                print("Stopped monitoring geofence: \(identifier)")
                if identifier == "race_start" { // Reset specific state if needed
                    DispatchQueue.main.async { self.isInStartRegion = false }
                }
                return
            }
        }
    }
    
    func stopAllGeofences() {
        for regionIdentifier in monitoredRegionIdentifiers {
            for region in manager.monitoredRegions where region.identifier == regionIdentifier {
                manager.stopMonitoring(for: region)
            }
        }
        monitoredRegionIdentifiers.removeAll()
        DispatchQueue.main.async { self.isInStartRegion = false } // Reset start region state
        print("Stopped all geofences.")
    }
    
    
    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Handle authorization changes - e.g., start tracking if permission granted
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            print("Location permission granted.")
            // You might want to auto-start tracking or re-check geofence states here.
            // For geofences, they usually continue monitoring if permission is granted.
        } else {
            print("Location permission status: \(manager.authorizationStatus)")
        }
    }
    
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let latestRaw = locations.last else { return }

            // Filter out poor accuracy updates early
            guard latestRaw.horizontalAccuracy >= 0 && latestRaw.horizontalAccuracy < 65 else { // Max 65m accuracy threshold
                print("LM Update: Poor accuracy: \(latestRaw.horizontalAccuracy)m. Update ignored for distance.")
                // You might still update currentLocation for map display if desired
                // self.currentLocation = latestRaw
                // self.userLocation = latestRaw.coordinate
                return
            }

            // Use the raw location or your filtered location
            let currentFilteredLocation = latestRaw // Replace with actual Kalman filtering if you re-enable it

            self.currentLocation = currentFilteredLocation
            self.userLocation = currentFilteredLocation.coordinate
            
            let currentSpeedMPS = currentFilteredLocation.speed // m/s from CLLocation
            self.speed = currentSpeedMPS >= 0 ? currentSpeedMPS : 0 // Ensure speed is not negative

            // Distance Calculation
            if let prev = previousLocation {
                // Ensure previous location was also valid before using it for distance.
                // currentFilteredLocation is already checked for accuracy.
                let delta = currentFilteredLocation.distance(from: prev)
                
                // Add delta only if it's a reasonable movement and positive.
                // Max delta can be tuned based on expected speed and update frequency.
                // For kCLDistanceFilterNone, updates can be every second. If speed is 10m/s, delta is ~10m.
                if delta > 0.2 && delta < 200 { // Reasonable delta: 0.2m to 200m per update
                    totalDistance += delta
                    // print("LM Update: Delta: \(String(format: "%.1f", delta))m, Total: \(String(format: "%.1f", totalDistance))m, Acc: \(String(format: "%.1f", currentFilteredLocation.horizontalAccuracy))m")
                } else if delta >= 200 {
                     print("LM Update: Large delta skipped: \(String(format: "%.1f", delta))m. Accuracy: Current \(currentFilteredLocation.horizontalAccuracy)m / Prev \(prev.horizontalAccuracy)m")
                }
            }
            // Always update previousLocation if current accuracy is good,
            // so next delta is from a good point.
            self.previousLocation = currentFilteredLocation
        }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
            DispatchQueue.main.async {
                // You might want to filter or check headingAccuracy
                if newHeading.headingAccuracy >= 0 {
                    self.currentHeading = newHeading
                }
            }
        }
    
    
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("LM Delegate: Did enter region \(region.identifier)")
        if region.identifier == "race_start" {
            DispatchQueue.main.async { self.isInStartRegion = true }
        }
        regionEntrySubject.send(region.identifier) // Send all entries
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("LM Delegate: Did exit region \(region.identifier)")
        if region.identifier == "race_start" {
            DispatchQueue.main.async { self.isInStartRegion = false }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        print("LM Delegate: State for \(region.identifier) is \(state == .inside ? "INSIDE" : "OUTSIDE")")
        if region.identifier == "race_start" {
            DispatchQueue.main.async { self.isInStartRegion = (state == .inside) }
        } else {
            // If user is already inside a checkpoint when monitoring starts for it
            if state == .inside {
                regionEntrySubject.send(region.identifier)
            }
        }
    }
}
