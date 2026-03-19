
//
//  RoutesListView.swift
//  Downshift
//
//  Created by Adil Rahmani on 5/12/25.
//

import SwiftUI
import CoreLocation

struct RoutesListView: View {
    @EnvironmentObject var appState: AppState

    @State private var searchText = ""
    @State private var selectedDifficulty: Difficulty? = nil
    @State private var showingRouteCreation = false

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    var filteredRoutes: [SavedRoute] {
        var routes = appState.savedRoutes
        if !searchText.isEmpty {
            routes = routes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        if let diff = selectedDifficulty {
            routes = routes.filter { $0.difficulty == diff }
        }
        return routes
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                difficultyFilterBar

                List {
                    if filteredRoutes.isEmpty {
                        if appState.savedRoutes.isEmpty {
                            ContentUnavailableView(
                                "No Routes Yet",
                                systemImage: "map",
                                description: Text("Tap '+' to create your first route.")
                            )
                        } else {
                            ContentUnavailableView.search(text: searchText.isEmpty ? selectedDifficulty?.rawValue ?? "" : searchText)
                        }
                    } else {
                        ForEach(filteredRoutes) { route in
                            NavigationLink(destination: RouteDetailView(route: route).onDisappear {
                                appState.loadRoutes()
                            }) {
                                RouteRow(route: route, appState: appState)
                            }
                        }
                        .onDelete(perform: deleteRoute)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("My Routes")
            .searchable(text: $searchText, prompt: "Search routes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        RouteCreationView()
                            .onDisappear { appState.loadRoutes() }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if !appState.savedRoutes.isEmpty { EditButton() }
                }
            }
            .onAppear { appState.loadRoutes() }
        }
    }

    private var difficultyFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedDifficulty == nil) {
                    selectedDifficulty = nil
                }
                ForEach(Difficulty.allCases, id: \.self) { diff in
                    FilterChip(title: diff.rawValue, isSelected: selectedDifficulty == diff) {
                        selectedDifficulty = selectedDifficulty == diff ? nil : diff
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    private func deleteRoute(at offsets: IndexSet) {
        // Map filtered indices back to appState.savedRoutes
        let routesToDelete = offsets.map { filteredRoutes[$0] }
        for route in routesToDelete {
            if let idx = appState.savedRoutes.firstIndex(where: { $0.id == route.id }) {
                appState.savedRoutes.remove(at: idx)
            }
        }
        appState.persistRoutes()
        appState.refreshFriendsAndFeed()
    }
}

// MARK: - Route Row
struct RouteRow: View {
    let route: SavedRoute
    let appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(route.name)
                    .font(.headline)
                Spacer()
                DifficultyBadge(difficulty: route.difficulty)
            }

            HStack(spacing: 12) {
                if let pb = appState.personalBest(for: route) {
                    Label(formatShortDuration(pb), systemImage: "trophy.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }

                Label("\(route.raceHistory.count) races", systemImage: "flag.checkered")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(shortDateFormatter.string(from: route.createdDate), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !route.tags.isEmpty {
                Text(route.tags.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var shortDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }
}

// MARK: - Preview
struct RoutesListView_Previews: PreviewProvider {
    static var previews: some View {
        RoutesListView()
            .environmentObject(AppState())
    }
}
