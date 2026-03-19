
//
//  AppState.swift
//  Downshift
//
//  Centralized app-wide state for user profile, routes, friends, and feed.
//

import Foundation
import SwiftUI
import Combine

private let userProfileKey = "userProfileData"
private let addedFriendNamesKey = "addedFriendNames"

class AppState: ObservableObject {
    @Published var userProfile: UserProfile
    @Published var savedRoutes: [SavedRoute] = []
    @Published var friends: [Friend] = []
    @Published var activityFeed: [ActivityFeedItem] = []
    @Published var selectedTab: Int = 0  // 0 = Home
    /// Names the user has explicitly added; persisted to UserDefaults.
    @Published var addedFriendNames: [String] = []

    init() {
        // Load or create user profile
        if let data = UserDefaults.standard.data(forKey: userProfileKey),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.userProfile = profile
        } else {
            self.userProfile = UserProfile()
        }

        // Load added friend names
        self.addedFriendNames = UserDefaults.standard.stringArray(forKey: addedFriendNamesKey) ?? []

        loadRoutes()
        refreshFriendsAndFeed()
    }

    // MARK: - Routes
    func loadRoutes() {
        guard let data = UserDefaults.standard.data(forKey: savedRoutesUserDefaultsKey) else {
            savedRoutes = []
            return
        }
        do {
            var routes = try JSONDecoder().decode([SavedRoute].self, from: data)
            routes.sort { $0.createdDate > $1.createdDate }
            savedRoutes = routes
        } catch {
            print("AppState: Error decoding routes: \(error)")
            savedRoutes = []
        }
        refreshFriendsAndFeed()
        updateUserStats()
    }

    func deleteRoute(at offsets: IndexSet) {
        savedRoutes.remove(atOffsets: offsets)
        persistRoutes()
        refreshFriendsAndFeed()
        updateUserStats()
    }

    func persistRoutes() {
        do {
            let data = try JSONEncoder().encode(savedRoutes)
            UserDefaults.standard.set(data, forKey: savedRoutesUserDefaultsKey)
        } catch {
            print("AppState: Error encoding routes: \(error)")
        }
    }

    // MARK: - Friends & Feed
    func refreshFriendsAndFeed() {
        // Only show friends the user has added
        let allMock = MockFriendGenerator.generateFriends(routes: savedRoutes)
        friends = allMock.filter { addedFriendNames.contains($0.name) }
        activityFeed = ActivityFeedGenerator.buildFeed(
            userRoutes: savedRoutes,
            userProfile: userProfile,
            friends: friends
        )
    }

    func addFriend(name: String) {
        guard !addedFriendNames.contains(name) else { return }
        addedFriendNames.append(name)
        UserDefaults.standard.set(addedFriendNames, forKey: addedFriendNamesKey)
        refreshFriendsAndFeed()
    }

    func removeFriend(name: String) {
        addedFriendNames.removeAll { $0 == name }
        UserDefaults.standard.set(addedFriendNames, forKey: addedFriendNamesKey)
        refreshFriendsAndFeed()
    }

    /// All mock names available to add (not yet added)
    var suggestedFriendNames: [String] {
        MockFriendGenerator.friendNames.filter { !addedFriendNames.contains($0) }
    }

    // MARK: - User Stats
    func updateUserStats() {
        let allResults = savedRoutes.flatMap { $0.raceHistory }
        userProfile.totalRaces = allResults.count
        userProfile.totalDistance = allResults.reduce(0) { $0 + $1.totalDistance }
        userProfile.totalTime = allResults.reduce(0) { $0 + $1.totalDuration }
        userProfile.bestAvgSpeed = allResults.map { $0.averageSpeed }.max() ?? 0

        var pbs: [String: TimeInterval] = [:]
        for route in savedRoutes {
            let best = route.raceHistory.min(by: { $0.totalDuration < $1.totalDuration })
            if let best = best {
                pbs[route.id.uuidString] = best.totalDuration
            }
        }
        userProfile.personalBests = pbs
        saveProfile()
    }

    func saveProfile() {
        if let data = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(data, forKey: userProfileKey)
        }
    }

    // MARK: - Helpers
    var recentRoutes: [SavedRoute] {
        // Routes that have been raced recently
        let raced = savedRoutes.filter { !$0.raceHistory.isEmpty }
            .sorted {
                let a = $0.raceHistory.max(by: { $0.date < $1.date })?.date ?? $0.createdDate
                let b = $1.raceHistory.max(by: { $0.date < $1.date })?.date ?? $1.createdDate
                return a > b
            }
        return Array(raced.prefix(5))
    }

    func personalBest(for route: SavedRoute) -> TimeInterval? {
        return route.raceHistory.min(by: { $0.totalDuration < $1.totalDuration })?.totalDuration
    }

    func thisWeekStats() -> (distance: Double, time: TimeInterval, races: Int) {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let weekResults = savedRoutes.flatMap { $0.raceHistory }.filter { $0.date >= startOfWeek }
        let dist = weekResults.reduce(0.0) { $0 + $1.totalDistance }
        let time = weekResults.reduce(0.0) { $0 + $1.totalDuration }
        return (dist, time, weekResults.count)
    }
}
