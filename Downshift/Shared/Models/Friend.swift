
//
//  Friend.swift
//  Downshift
//
//  Created by Adil Rahmani on 5/12/25.
//

import Foundation

struct Friend: Identifiable {
    let id: UUID
    var name: String
    var avatarSystemName: String
    var recentRaces: [FriendRace]
    var personalBests: [String: TimeInterval]  // routeId.uuidString: time

    struct FriendRace: Identifiable {
        let id: UUID
        let routeId: UUID
        let routeName: String
        let totalDuration: TimeInterval
        let averageSpeed: Double  // m/s
        let totalDistance: Double  // meters
        let date: Date
    }
}

// MARK: - Mock Friend Generator using seeded RNG
struct MockFriendGenerator {
    static let friendNames = [
        "Jake Martinez", "Sarah Chen", "Mike Thompson",
        "Emma Wilson", "Carlos Rivera", "Lily Park",
        "Noah Davis", "Ava Johnson", "Liam Brown"
    ]
    static let avatarNames = [
        "person.circle", "person.circle.fill", "figure.run",
        "figure.walk", "car.fill", "bolt.circle.fill",
        "star.circle.fill", "flame.circle.fill", "wind.circle.fill"
    ]

    static func generateFriends(routes: [SavedRoute]) -> [Friend] {
        return friendNames.enumerated().map { index, name in
            generateFriend(seed: index + 1, name: name, routes: routes)
        }
    }

    private static func generateFriend(seed: Int, name: String, routes: [SavedRoute]) -> Friend {
        var rng = SeededRandomNumberGenerator(seed: seed)
        let avatarIndex = Int.random(in: 0..<avatarNames.count, using: &rng)

        var races: [Friend.FriendRace] = []
        for route in routes {
            let raceCount = Int.random(in: 0...3, using: &rng)
            for _ in 0..<raceCount {
                let baseDuration = Double.random(in: 120...600, using: &rng)
                let distance = Double.random(in: 500...5000, using: &rng)
                let speed = distance / baseDuration
                let daysAgo = Double.random(in: 0...30, using: &rng)
                races.append(Friend.FriendRace(
                    id: UUID(),
                    routeId: route.id,
                    routeName: route.name,
                    totalDuration: baseDuration,
                    averageSpeed: speed,
                    totalDistance: distance,
                    date: Date().addingTimeInterval(-daysAgo * 86400)
                ))
            }
        }
        races.sort { $0.date > $1.date }

        var pbs: [String: TimeInterval] = [:]
        for route in routes {
            let routeRaces = races.filter { $0.routeId == route.id }
            if let best = routeRaces.min(by: { $0.totalDuration < $1.totalDuration }) {
                pbs[route.id.uuidString] = best.totalDuration
            }
        }

        return Friend(
            id: UUID(),
            name: name,
            avatarSystemName: avatarNames[avatarIndex],
            recentRaces: Array(races.prefix(5)),
            personalBests: pbs
        )
    }
}

// Seeded random number generator for deterministic mock data
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
