//
//  RoutesListView.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/12/25.
//


import SwiftUI
import CoreLocation // Import needed for SavedRoute

struct RoutesListView: View {
    @State private var savedRoutes: [SavedRoute] = []

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter(); formatter.dateStyle = .medium; formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        NavigationStack {
            List {
                if savedRoutes.isEmpty {
                    Text("No saved routes yet. Tap '+' to create one!")
                        .foregroundColor(.secondary).padding()
                } else {
                    ForEach(savedRoutes) { route in
                        // Wrap the content in NavigationLink
                        NavigationLink(destination: RouteDetailView(route: route)) {
                            // Row Content
                            VStack(alignment: .leading) {
                                Text(route.name).font(.headline)
                                Text("Created: \(route.createdDate, formatter: dateFormatter)")
                                    .font(.caption).foregroundColor(.secondary)
                                if !route.raceHistory.isEmpty {
                                     Text("Raced \(route.raceHistory.count) times")
                                          .font(.caption).foregroundColor(.blue)
                                }
                            }
                        } // End NavigationLink
                    }
                    .onDelete(perform: deleteRoute)
                }
            }
            .navigationTitle("My Routes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink { RouteCreationView() } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !savedRoutes.isEmpty { EditButton() }
                }
            }
            .onAppear(perform: loadRoutes) // Load routes when view appears
        }
    }

    private func loadRoutes() {
         guard let data = UserDefaults.standard.data(forKey: savedRoutesUserDefaultsKey) else {
             self.savedRoutes = []; return
         }
         do {
             let decoder = JSONDecoder()
             // Set decoding strategy for dates if needed, assuming default ISO8601 or similar works
             // decoder.dateDecodingStrategy = .iso8601
             self.savedRoutes = try decoder.decode([SavedRoute].self, from: data)
              // Sort routes by date, newest first
              self.savedRoutes.sort { $0.createdDate > $1.createdDate }
         } catch {
             print("Error decoding saved routes (maybe due to data structure change?): \(error)")
             self.savedRoutes = []
             // Consider clearing old data if decode fails consistently after model change
             // UserDefaults.standard.removeObject(forKey: savedRoutesUserDefaultsKey)
         }
    }

    private func deleteRoute(at offsets: IndexSet) {
        savedRoutes.remove(atOffsets: offsets)
        do {
            let data = try JSONEncoder().encode(savedRoutes)
            UserDefaults.standard.set(data, forKey: savedRoutesUserDefaultsKey)
        } catch {
            print("Error encoding after deletion: \(error)")
            // Consider reloading to ensure consistency if save fails
            // loadRoutes()
        }
    }
}
// MARK: - Preview (Optional)
struct RoutesListView_Previews: PreviewProvider {
    static var previews: some View {
        // Example preview setup
        RoutesListView()
            .onAppear {
                // Add sample data to UserDefaults for preview if needed
                let sampleCoords = [
                    CLLocationCoordinate2D(latitude: 42.49, longitude: -71.45),
                    CLLocationCoordinate2D(latitude: 42.50, longitude: -71.46)
                ]
                let sampleRoutes = [
                    SavedRoute(name: "Morning Jog", coordinates: sampleCoords, createdDate: Date().addingTimeInterval(-86400)),
                    SavedRoute(name: "Park Loop", coordinates: sampleCoords)
                ]
                if let data = try? JSONEncoder().encode(sampleRoutes) {
                     UserDefaults.standard.set(data, forKey: savedRoutesUserDefaultsKey)
                 } else {
                      UserDefaults.standard.removeObject(forKey: savedRoutesUserDefaultsKey)
                 }

            }
    }
}
