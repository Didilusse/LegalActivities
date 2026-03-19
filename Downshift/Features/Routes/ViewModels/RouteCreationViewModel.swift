//
//  RouteCreationViewModel.swift
//  Downshift
//
//  Created by Adil Rahmani on 5/12/25.
//
import SwiftUI
import MapKit
import Combine
import CoreLocation


let savedRoutesUserDefaultsKey = "savedRoutesData"

class RouteCreationViewModel: ObservableObject {
    @Published var annotations: [LocationPin] = []
    @Published var region = MKCoordinateRegion()
    @Published var routeSegments: [MKPolyline] = []
    @Published var selectedAnnotation: LocationPin? = nil
    
    // Undo/Redo stacks
    @Published var undoStack: [[LocationPin]] = []
    @Published var redoStack: [[LocationPin]] = []
    
    // Computed route stats
    @Published var totalRouteDistance: Double = 0 // in meters
    @Published var estimatedDuration: TimeInterval = 0 // in seconds
    @Published var routeCreationNotice: String? = nil
    @Published var hasUnroutableSegments: Bool = false
    
    private var directionsTasks: [MKDirections] = []
    private var debounceTask: Task<Void, Never>? = nil
    
    // MARK: - Undo/Redo
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    private func saveStateForUndo() {
        undoStack.append(annotations)
        redoStack.removeAll() // Clear redo when new action is taken
        // Limit undo stack size
        if undoStack.count > 20 {
            undoStack.removeFirst()
        }
    }
    
    func undo() {
        guard let previousState = undoStack.popLast() else { return }
        redoStack.append(annotations)
        annotations = previousState
        selectedAnnotation = nil
        calculateRouteSegments()
    }
    
    func redo() {
        guard let nextState = redoStack.popLast() else { return }
        undoStack.append(annotations)
        annotations = nextState
        selectedAnnotation = nil
        calculateRouteSegments()
    }
    
    // MARK: - Quick Actions
    func reverseRoute() {
        guard annotations.count >= 2 else { return }
        saveStateForUndo()
        
        // Swap start and end types
        var newAnnotations: [LocationPin] = []
        for annotation in annotations.reversed() {
            var newPin = annotation
            if annotation.type == .start {
                newPin = LocationPin(coordinate: annotation.coordinate, type: .end)
            } else if annotation.type == .end {
                newPin = LocationPin(coordinate: annotation.coordinate, type: .start)
            }
            newAnnotations.append(newPin)
        }
        
        // Reorder so start is first and end is last
        if let startIdx = newAnnotations.firstIndex(where: { $0.type == .start }) {
            let start = newAnnotations.remove(at: startIdx)
            newAnnotations.insert(start, at: 0)
        }
        if let endIdx = newAnnotations.firstIndex(where: { $0.type == .end }) {
            let end = newAnnotations.remove(at: endIdx)
            newAnnotations.append(end)
        }
        
        annotations = newAnnotations
        selectedAnnotation = nil
        calculateRouteSegments()
    }
    
    func clearAll() {
        guard !annotations.isEmpty else { return }
        saveStateForUndo()
        annotations.removeAll()
        routeSegments.removeAll()
        selectedAnnotation = nil
        totalRouteDistance = 0
        estimatedDuration = 0
    }
    
    // MARK: - Computed Properties
    var canSaveRoute: Bool {
        let hasStart = annotations.contains { $0.type == .start }
        let hasEnd = annotations.contains { $0.type == .end }
        let expectedSegmentCount = max(0, annotations.count - 1)
        return hasStart
            && hasEnd
            && annotations.count >= 2
            && !hasUnroutableSegments
            && routeSegments.count == expectedSegmentCount
    }
    
    var checkpoints: [LocationPin] {
            annotations.filter { $0.type == .checkpoint }
        }
    
    // MARK: - Route Creation Methods
    func addAnnotation(at coordinate: CLLocationCoordinate2D, type: LocationPin.PointType) {
            DispatchQueue.main.async {
                self.saveStateForUndo()
                self.selectedAnnotation = nil
                let newAnnotation = LocationPin(coordinate: coordinate, type: type)

                if type == .start || type == .end {
                    self.annotations.removeAll { $0.type == type }
                }

                if type == .start {
                    self.annotations.insert(newAnnotation, at: 0)
                    if let endIdx = self.annotations.firstIndex(where: { $0.type == .end }) {
                        let endAnnotation = self.annotations.remove(at: endIdx)
                        self.annotations.append(endAnnotation)
                    }
                } else if type == .end {
                    self.annotations.append(newAnnotation)
                } else { // Checkpoint
                    if let endIdx = self.annotations.firstIndex(where: { $0.type == .end }) {
                        self.annotations.insert(newAnnotation, at: endIdx)
                    } else {
                        self.annotations.append(newAnnotation)
                    }
                }
                self.calculateRouteSegments()
            }
        }
    
    func updateAnnotationPosition(_ annotationToUpdate: LocationPin, newCoordinate: CLLocationCoordinate2D) {
            DispatchQueue.main.async {
                if let index = self.annotations.firstIndex(where: { $0.id == annotationToUpdate.id }) {
                    self.annotations[index].coordinate = newCoordinate // Update the coordinate directly

                    // If the selected annotation was the one moved, update its reference if needed
                    // (though LocationPin is a struct, so the selectedAnnotation might be a copy;
                    //  it's often better to re-select or clear selection after a drag)
                    if self.selectedAnnotation?.id == annotationToUpdate.id {
                        // self.selectedAnnotation = self.annotations[index] // Re-assign if it's a class
                        // For struct, if you want selectedAnnotation to reflect the change, you'd re-select.
                        // For simplicity, let's clear selection after drag.
                        self.selectedAnnotation = nil
                    }
                    
                    self.calculateRouteSegments() // Recalculate route with the new position
                }
            }
        }
    
    func selectAnnotation(_ annotation: LocationPin?) {
            DispatchQueue.main.async {
                if self.selectedAnnotation?.id == annotation?.id {
                    self.selectedAnnotation = nil
                } else {
                    self.selectedAnnotation = annotation
                }
            }
        }

        func removeAnnotation(_ annotationToRemove: LocationPin) {
            DispatchQueue.main.async {
                self.saveStateForUndo()
                self.annotations.removeAll { $0.id == annotationToRemove.id }
                if self.selectedAnnotation?.id == annotationToRemove.id {
                    self.selectedAnnotation = nil
                }
                self.calculateRouteSegments()
            }
        }

        func removeSelectedAnnotation() {
            guard let selected = selectedAnnotation else { return }
            removeAnnotation(selected)
        }
    
    func deleteCheckpointsFromList(atOffsets offsets: IndexSet) {
            DispatchQueue.main.async {
                // Get the actual checkpoint objects to be deleted
                let checkpointsToDelete = offsets.map { self.checkpoints[$0] }
                for cp in checkpointsToDelete {
                    // Remove from the main annotations array
                    self.annotations.removeAll { $0.id == cp.id }
                    if self.selectedAnnotation?.id == cp.id {
                        self.selectedAnnotation = nil
                    }
                }
                self.calculateRouteSegments()
            }
        }
    
    func moveCheckpointInList(from sourceOffsets: IndexSet, to destinationOffset: Int) {
            DispatchQueue.main.async {
                // 1. Get the actual checkpoint objects being moved from the filtered list
                let checkpointsToMove = sourceOffsets.map { self.checkpoints[$0] }
                guard let checkpointToMove = checkpointsToMove.first else { return } // Assuming moving one at a time for now

                // 2. Find the range of checkpoints in the main 'annotations' array
                guard self.annotations.firstIndex(where: { $0.type == .checkpoint }) != nil,
                      self.annotations.lastIndex(where: { $0.type == .checkpoint }) != nil
                else {
                    // No checkpoints to move, or something is wrong
                    return
                }
                
                // 3. Remove the checkpoint from its old position in the main 'annotations' array
                guard let originalIndexInAnnotations = self.annotations.firstIndex(where: { $0.id == checkpointToMove.id }) else { return }
                let movedItem = self.annotations.remove(at: originalIndexInAnnotations)

                // 4. Calculate the new insertion index in the main 'annotations' array
                // 'destinationOffset' is relative to the filtered 'checkpoints' list.
                // If moving to the end of the checkpoints list
                var newIndexInAnnotations: Int
                if destinationOffset >= self.checkpoints.count { // checkpoints.count is count *before* removal for this calc
                     // Place it just before the 'End' pin, or at the end if no 'End' pin (shouldn't happen with good logic)
                     newIndexInAnnotations = self.annotations.firstIndex(where: {$0.type == .end}) ?? self.annotations.count
                } else {
                    // Get the checkpoint that will be *after* the moved item in the filtered list
                    let destinationCheckpointInFilteredList = self.checkpoints[destinationOffset]
                    // Find its index in the main annotations array
                    newIndexInAnnotations = self.annotations.firstIndex(where: { $0.id == destinationCheckpointInFilteredList.id }) ?? (self.annotations.firstIndex(where: {$0.type == .end}) ?? self.annotations.count)
                }
                
                self.annotations.insert(movedItem, at: newIndexInAnnotations)

                self.selectedAnnotation = nil // Deselect after reordering
                self.calculateRouteSegments()
            }
        }

    
    private func calculateRouteSegments() {
        // Debounce: cancel any pending calculation and wait 0.4s for the user to stop making changes
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(400))
            } catch {
                return // Cancelled — a newer call came in
            }
            await self.runRouteCalculation()
        }
    }

    @MainActor
    private func runRouteCalculation() async {
        directionsTasks.forEach { $0.cancel() }
        directionsTasks.removeAll()

        let pins = annotations
        guard pins.count >= 2 else {
            routeSegments = []
            totalRouteDistance = 0
            estimatedDuration = 0
            hasUnroutableSegments = false
            return
        }

        // Reset displayed route while recalculating so Save remains disabled until complete.
        routeSegments = []
        totalRouteDistance = 0
        estimatedDuration = 0
        hasUnroutableSegments = false

        var segments: [MKPolyline] = []
        var totalDistance: Double = 0
        var totalTime: TimeInterval = 0
        var failedSegmentNumbers: [Int] = []
        var firstDirectionsError: String? = nil

        // Process segments one at a time to stay well under the 50 req/60s limit.
        // A ~300ms gap between requests keeps throughput at ~3/s (180/min), safely under the cap.
        for i in 0..<(pins.count - 1) {
            // Check for cancellation before each request (user may have added another pin)
            guard !Task.isCancelled else { return }

            let request = MKDirections.Request()
            request.source      = MKMapItem(placemark: MKPlacemark(coordinate: pins[i].coordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: pins[i + 1].coordinate))
            request.transportType = .automobile

            let directions = MKDirections(request: request)
            directionsTasks.append(directions)

            do {
                let response = try await directions.calculate()
                if let route = response.routes.first {
                    segments.append(route.polyline)
                    totalDistance += route.distance
                    totalTime += route.expectedTravelTime
                }
            } catch {
                print("Error or no route for segment \(i): \(error.localizedDescription)")
                failedSegmentNumbers.append(i + 1)
                if firstDirectionsError == nil {
                    firstDirectionsError = error.localizedDescription
                }
            }

            // Small pause between requests to avoid rate-limiting
            if i < pins.count - 2 {
                try? await Task.sleep(for: .milliseconds(300))
            }
        }

        guard !Task.isCancelled else { return }
        routeSegments = segments
        totalRouteDistance = totalDistance
        estimatedDuration = totalTime

        if failedSegmentNumbers.isEmpty {
            hasUnroutableSegments = false
            routeCreationNotice = nil
        } else {
            hasUnroutableSegments = true
            let list = failedSegmentNumbers.prefix(4).map(String.init).joined(separator: ", ")
            let moreSuffix = failedSegmentNumbers.count > 4 ? "..." : ""
            let reason = firstDirectionsError ?? "Directions not available"
            routeCreationNotice = "Could not route segment \(list)\(moreSuffix) (\(reason)). Move points onto nearby roads before saving."
        }

        print("Route segments updated: \(segments.count), Distance: \(totalDistance)m, Time: \(totalTime)s")
    }
    
    func getCheckpointNumber(for locationPin: LocationPin) -> Int? {
        guard locationPin.type == .checkpoint else { return nil }
        let checkpointIndex = annotations.filter { $0.type == .checkpoint }.firstIndex { $0.id == locationPin.id }
        return checkpointIndex.map { $0 + 1 }
    }
    
    // MARK: - Saving
    func saveRoute(name: String, difficulty: Difficulty = .medium, tags: [String] = [], location: String? = nil) -> Bool {
        if hasUnroutableSegments {
            routeCreationNotice = "This route has unroutable segments. Adjust points so each segment is on a drivable road."
            return false
        }

        guard canSaveRoute else {
            print("Cannot save route: Missing start or end point.")
            routeCreationNotice = "Cannot save route yet. Add both a start and finish point."
            return false
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            print("Cannot save route: Name is empty.")
            routeCreationNotice = "Route name cannot be empty."
            return false
        }

        let coordinates = self.annotations.map { $0.coordinate }
        let trimmedLocation = location?.trimmingCharacters(in: .whitespacesAndNewlines)
        let newRoute = SavedRoute(name: trimmedName, coordinates: coordinates, difficulty: difficulty, tags: tags, location: trimmedLocation?.isEmpty == true ? nil : trimmedLocation)
        
        // Load existing, append, and save back
        var currentSavedRoutes: [SavedRoute] = []
        if let data = UserDefaults.standard.data(forKey: savedRoutesUserDefaultsKey) {
            do {
                let decoder = JSONDecoder()
                currentSavedRoutes = try decoder.decode([SavedRoute].self, from: data)
            } catch {
                print("Error decoding existing saved routes before saving: \(error)")
                // Decide if you want to overwrite or fail
                // return false
            }
        }
        
        // Optional: Check for duplicate names before appending
        // if currentSavedRoutes.contains(where: { $0.name == newRoute.name }) {
        //     print("Cannot save route: A route with this name already exists.")
        //     return false
        // }
        
        currentSavedRoutes.append(newRoute)
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(currentSavedRoutes)
            UserDefaults.standard.set(data, forKey: savedRoutesUserDefaultsKey)
            print("Route '\(newRoute.name)' saved successfully. Total routes: \(currentSavedRoutes.count)")
            return true // Indicate success
        } catch {
            print("Error encoding saved routes: \(error)")
            routeCreationNotice = "Failed to save route. Please try again."
            return false // Indicate failure
        }
    }
    
    // MARK: - Map Interaction & Clearing
    func clearCurrentRoute() {
        annotations.removeAll()
        routeSegments.removeAll()
        // Consider resetting region here if desired
    }
    
    func centerMapOnUser(mapView: MKMapView) {
        DispatchQueue.main.async {
            if let userLocation = mapView.userLocation.location?.coordinate {
                self.region = MKCoordinateRegion(
                    center: userLocation,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
                mapView.setRegion(self.region, animated: true) // Also set it on the map
            }
        }
    }
    
    func zoomToFitRouteSegments(mapView: MKMapView) {
        DispatchQueue.main.async {
            guard !self.routeSegments.isEmpty else {
                self.zoomToFitAnnotations(mapView: mapView)
                return
            }
            var zoomRect = MKMapRect.null
            self.routeSegments.forEach { segment in
                zoomRect = zoomRect.union(segment.boundingMapRect)
            }
            if !zoomRect.isNull && !zoomRect.isEmpty {
                mapView.setVisibleMapRect(zoomRect, edgePadding: UIEdgeInsets(top: 60, left: 60, bottom: 60, right: 60), animated: true)
            } else {
                self.zoomToFitAnnotations(mapView: mapView)
            }
        }
    }
    
    private func zoomToFitAnnotations(mapView: MKMapView) {
        DispatchQueue.main.async {
            guard !self.annotations.isEmpty else { return }
            var zoomRect = MKMapRect.null
            self.annotations.forEach { annotation in
                let point = MKMapPoint(annotation.coordinate)
                let pointRect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
                zoomRect = zoomRect.union(pointRect)
            }
            if !zoomRect.isNull && !zoomRect.isEmpty {
                mapView.setVisibleMapRect(zoomRect, edgePadding: UIEdgeInsets(top: 60, left: 60, bottom: 60, right: 60), animated: true)
            }
        }
    }
}
