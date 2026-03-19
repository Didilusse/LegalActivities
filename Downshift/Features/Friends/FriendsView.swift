//
//  FriendsView.swift
//  Downshift
//
//  Social tab: friends list + recent races feed, with Add Friend support.
//

import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFriend: Friend? = nil
    @State private var showAddFriend = false

    var body: some View {
        NavigationStack {
            Group {
                if appState.friends.isEmpty {
                    emptyView
                } else {
                    socialFeed
                }
            }
            .navigationTitle("Social")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(item: $selectedFriend) { friend in
                FriendDetailView(friend: friend)
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView()
                    .environmentObject(appState)
            }
            .onAppear {
                appState.refreshFriendsAndFeed()
            }
        }
    }

    // MARK: - Main feed (friends + recent races interleaved)
    private var socialFeed: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                friendsCarousel
                recentRacesFeed
            }
            .padding(.vertical, 12)
        }
    }

    // MARK: - Horizontal friends carousel
    private var friendsCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Friends")
                    .font(.headline)
                    .padding(.horizontal)
                Spacer()
                Button {
                    showAddFriend = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(appState.friends) { friend in
                        FriendAvatarCard(friend: friend) {
                            selectedFriend = friend
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Chronological recent races feed
    private var recentRacesFeed: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Races")
                .font(.headline)
                .padding(.horizontal)

            let allRaces = appState.friends
                .flatMap { friend in friend.recentRaces.map { (friend: friend, race: $0) } }
                .sorted { $0.race.date > $1.race.date }

            if allRaces.isEmpty {
                Text("No recent races yet — your friends haven't raced any of your routes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(allRaces.enumerated()), id: \.element.race.id) { idx, pair in
                        RecentRaceRow(
                            friend: pair.friend,
                            race: pair.race,
                            units: appState.userProfile.unitPreference
                        ) {
                            selectedFriend = pair.friend
                        }
                        if idx < allRaces.count - 1 {
                            Divider().padding(.leading, 72)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Empty state
    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.2.slash")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("No Friends Yet")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Add friends to see their races\nand compete on leaderboards.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showAddFriend = true
            } label: {
                Label("Add a Friend", systemImage: "person.badge.plus")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(Color.blue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Friend Avatar Card (carousel item)
private struct FriendAvatarCard: View {
    let friend: Friend
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: friend.avatarSystemName)
                        .font(.system(size: 28))
                        .foregroundStyle(.blue)
                        .frame(width: 64, height: 64)
                        .background(Color.blue.opacity(0.1), in: Circle())

                    // Activity indicator — green if raced in last 7 days
                    if let last = friend.recentRaces.first,
                       Date().timeIntervalSince(last.date) < 7 * 86400 {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                            .offset(x: 2, y: 2)
                    }
                }

                Text(friend.name.components(separatedBy: " ").first ?? friend.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let last = friend.recentRaces.first {
                    Text(formatShortDuration(last.totalDuration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No races")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Race Row
private struct RecentRaceRow: View {
    let friend: Friend
    let race: Friend.FriendRace
    let units: UnitPreference
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: friend.avatarSystemName)
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.1), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(friend.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("raced")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text(race.routeName)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text(race.date.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(formatShortDuration(race.totalDuration))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    Text(units.formatDistance(race.totalDistance))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Friend Sheet
struct AddFriendView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var suggestions: [String] {
        let base = appState.suggestedFriendNames
        guard !searchText.isEmpty else { return base }
        return base.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                if suggestions.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(suggestions, id: \.self) { name in
                        HStack(spacing: 14) {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)

                            Text(name)
                                .font(.body)

                            Spacer()

                            Button {
                                appState.addFriend(name: name)
                            } label: {
                                Text("Add")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.blue, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Already added
                if !appState.addedFriendNames.isEmpty {
                    Section("Added") {
                        ForEach(appState.addedFriendNames, id: \.self) { name in
                            HStack(spacing: 14) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(name)
                                    .font(.body)
                                Spacer()
                                Button(role: .destructive) {
                                    appState.removeFriend(name: name)
                                } label: {
                                    Text("Remove")
                                        .font(.subheadline)
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Add Friends")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search by name")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Friend Detail View
struct FriendDetailView: View {
    let friend: Friend
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    profileHeader
                    statsSection
                    personalBestsSection
                    recentRacesSection
                }
                .padding(.vertical)
            }
            .navigationTitle(friend.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: friend.avatarSystemName)
                .font(.system(size: 56))
                .foregroundStyle(.blue)
                .frame(width: 88, height: 88)
                .background(Color.blue.opacity(0.1), in: Circle())

            Text(friend.name)
                .font(.title2)
                .fontWeight(.bold)

            Text("\(friend.recentRaces.count) recent races")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var statsSection: some View {
        let units = appState.userProfile.unitPreference
        let totalDist = friend.recentRaces.reduce(0.0) { $0 + $1.totalDistance }
        let bestSpeed = friend.recentRaces.map { $0.averageSpeed }.max() ?? 0

        return VStack(alignment: .leading, spacing: 10) {
            Text("Stats")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 0) {
                statCell(value: "\(friend.recentRaces.count)", label: "Races")
                Divider().frame(height: 40)
                statCell(value: units.formatDistance(totalDist), label: "Total Dist.")
                Divider().frame(height: 40)
                statCell(value: units.formatSpeed(bestSpeed), label: "Best Speed")
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var personalBestsSection: some View {
        Group {
            if !friend.personalBests.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Personal Bests")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(spacing: 0) {
                        ForEach(Array(friend.personalBests.sorted { $0.value < $1.value }.prefix(5)), id: \.key) { routeIdStr, time in
                            let routeName = appState.savedRoutes.first { $0.id.uuidString == routeIdStr }?.name ?? "Unknown Route"
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                                Text(routeName)
                                    .font(.subheadline)
                                Spacer()
                                Text(formatShortDuration(time))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                            Divider().padding(.horizontal)
                        }
                    }
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
            }
        }
    }

    private var recentRacesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Races")
                .font(.headline)
                .padding(.horizontal)

            if friend.recentRaces.isEmpty {
                Text("No races yet.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(friend.recentRaces) { race in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(race.routeName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(race.date.formatted(.relative(presentation: .named)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(formatShortDuration(race.totalDuration))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(appState.userProfile.unitPreference.formatDistance(race.totalDistance))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        Divider().padding(.horizontal)
                    }
                }
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    FriendsView()
        .environmentObject(AppState())
}
