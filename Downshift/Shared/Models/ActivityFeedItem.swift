
//
//  ActivityFeedItem.swift
//  Downshift
//
//  Created by Adil Rahmani on 5/12/25.
//

import Foundation

enum ActivityType {
    case personalBestBeaten
    case routeCompleted
    case friendRaced
    case challengeAccepted
    case challengeCompleted
}

struct ActivityFeedItem: Identifiable {
    let id: UUID
    var type: ActivityType
    var actorName: String         // "You" or friend name
    var routeName: String
    var routeId: UUID?
    var duration: TimeInterval?
    var previousBest: TimeInterval?  // for personalBestBeaten
    var timestamp: Date
    var description: String

    init(
        id: UUID = UUID(),
        type: ActivityType,
        actorName: String,
        routeName: String,
        routeId: UUID? = nil,
        duration: TimeInterval? = nil,
        previousBest: TimeInterval? = nil,
        timestamp: Date = Date(),
        description: String = ""
    ) {
        self.id = id
        self.type = type
        self.actorName = actorName
        self.routeName = routeName
        self.routeId = routeId
        self.duration = duration
        self.previousBest = previousBest
        self.timestamp = timestamp
        self.description = description
    }

    var iconName: String {
        switch type {
        case .personalBestBeaten: return "trophy.fill"
        case .routeCompleted: return "checkmark.circle.fill"
        case .friendRaced: return "person.2.fill"
        case .challengeAccepted: return "flag.fill"
        case .challengeCompleted: return "flag.checkered"
        }
    }

    var relativeTimestamp: String {
        let seconds = Date().timeIntervalSince(timestamp)
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h ago" }
        if seconds < 172800 { return "Yesterday" }
        return "\(Int(seconds / 86400))d ago"
    }
}

// MARK: - Feed Generator
struct ActivityFeedGenerator {
    static func buildFeed(userRoutes: [SavedRoute], userProfile: UserProfile, friends: [Friend]) -> [ActivityFeedItem] {
        var items: [ActivityFeedItem] = []

        // User's own race results
        for route in userRoutes {
            let sortedResults = route.raceHistory.sorted { $0.date > $1.date }
            for (idx, result) in sortedResults.prefix(3).enumerated() {
                let prevBest: TimeInterval? = idx > 0 ? sortedResults[idx - 1].totalDuration : nil
                let isPersonalBest = prevBest.map { result.totalDuration < $0 } ?? false

                if isPersonalBest, let pb = prevBest {
                    items.append(ActivityFeedItem(
                        type: .personalBestBeaten,
                        actorName: "You",
                        routeName: route.name,
                        routeId: route.id,
                        duration: result.totalDuration,
                        previousBest: pb,
                        timestamp: result.date,
                        description: "Beat personal best"
                    ))
                } else {
                    items.append(ActivityFeedItem(
                        type: .routeCompleted,
                        actorName: "You",
                        routeName: route.name,
                        routeId: route.id,
                        duration: result.totalDuration,
                        timestamp: result.date,
                        description: "Completed route"
                    ))
                }
            }
        }

        // Friends' recent races
        for friend in friends {
            for race in friend.recentRaces.prefix(2) {
                items.append(ActivityFeedItem(
                    type: .friendRaced,
                    actorName: friend.name,
                    routeName: race.routeName,
                    routeId: race.routeId,
                    duration: race.totalDuration,
                    timestamp: race.date,
                    description: "\(friend.name) raced \(race.routeName)"
                ))
            }
        }

        return items.sorted { $0.timestamp > $1.timestamp }
    }
}
