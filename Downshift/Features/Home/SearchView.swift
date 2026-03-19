//
//  SearchView.swift
//  Downshift
//
//  Global search across routes, friends, and activity feed items.
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @FocusState private var isFocused: Bool

    // MARK: - Filtered results

    private var routeResults: [SavedRoute] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return appState.savedRoutes.filter { route in
            route.name.localizedCaseInsensitiveContains(query) ||
            route.difficulty.rawValue.localizedCaseInsensitiveContains(query) ||
            route.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var friendResults: [Friend] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return appState.friends.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var activityResults: [ActivityFeedItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        return appState.activityFeed.filter { item in
            item.routeName.localizedCaseInsensitiveContains(query) ||
            item.actorName.localizedCaseInsensitiveContains(query)
        }
    }

    private var hasResults: Bool {
        !routeResults.isEmpty || !friendResults.isEmpty || !activityResults.isEmpty
    }

    private var isQueryEmpty: Bool {
        query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()

            if isQueryEmpty {
                suggestionsView
            } else if !hasResults {
                noResultsView
            } else {
                resultsList
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { isFocused = true }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Routes, friends, activity…", text: $query)
                .focused($isFocused)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - Suggestions (empty query)

    private var suggestionsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !appState.savedRoutes.isEmpty {
                    suggestionSection(title: "Your Routes", icon: "map.fill", color: .blue) {
                        ForEach(appState.savedRoutes.prefix(4)) { route in
                            NavigationLink {
                                RouteStatsView(route: route).environmentObject(appState)
                            } label: {
                                suggestionRow(
                                    title: route.name,
                                    subtitle: "\(route.difficulty.rawValue) · \(route.raceHistory.count) races",
                                    icon: "map.fill",
                                    color: difficultyColor(route.difficulty)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !appState.friends.isEmpty {
                    suggestionSection(title: "Friends", icon: "person.2.fill", color: .green) {
                        ForEach(appState.friends.prefix(4)) { friend in
                            suggestionRow(
                                title: friend.name,
                                subtitle: "\(friend.recentRaces.count) recent races",
                                icon: friend.avatarSystemName,
                                color: .green
                            )
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private func suggestionSection<Content: View>(
        title: String, icon: String, color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.headline)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            if !routeResults.isEmpty {
                Section {
                    ForEach(routeResults) { route in
                        NavigationLink {
                            RouteStatsView(route: route).environmentObject(appState)
                        } label: {
                            routeResultRow(route)
                        }
                    }
                } header: {
                    sectionHeader("Routes", count: routeResults.count, icon: "map.fill", color: .blue)
                }
            }

            if !friendResults.isEmpty {
                Section {
                    ForEach(friendResults) { friend in
                        friendResultRow(friend)
                    }
                } header: {
                    sectionHeader("Friends", count: friendResults.count, icon: "person.2.fill", color: .green)
                }
            }

            if !activityResults.isEmpty {
                Section {
                    ForEach(activityResults) { item in
                        activityResultRow(item)
                    }
                } header: {
                    sectionHeader("Activity", count: activityResults.count, icon: "bolt.fill", color: .orange)
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.easeInOut(duration: 0.2), value: query)
    }

    // MARK: - Row Types

    private func routeResultRow(_ route: SavedRoute) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(difficultyColor(route.difficulty).opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "map.fill")
                    .foregroundStyle(difficultyColor(route.difficulty))
            }
            VStack(alignment: .leading, spacing: 3) {
                highlightedText(route.name, query: query)
                    .font(.subheadline).fontWeight(.semibold)
                HStack(spacing: 6) {
                    Text(route.difficulty.rawValue)
                        .font(.caption)
                        .foregroundStyle(difficultyColor(route.difficulty))
                    if !route.tags.isEmpty {
                        Text("·").font(.caption).foregroundStyle(.secondary)
                        Text(route.tags.joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            if let pb = appState.personalBest(for: route) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(formatShortDuration(pb))
                        .font(.caption).fontWeight(.bold)
                    Text("PB").font(.caption2).foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func friendResultRow(_ friend: Friend) -> some View {
        HStack(spacing: 12) {
            Image(systemName: friend.avatarSystemName)
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 40, height: 40)
                .background(Color.green.opacity(0.1))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                highlightedText(friend.name, query: query)
                    .font(.subheadline).fontWeight(.semibold)
                Text("\(friend.recentRaces.count) recent race\(friend.recentRaces.count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func activityResultRow(_ item: ActivityFeedItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.iconName)
                .font(.title3)
                .foregroundStyle(activityColor(item.type))
                .frame(width: 36, height: 36)
                .background(activityColor(item.type).opacity(0.1))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                (Text(item.actorName).fontWeight(.semibold) + Text(" on ") + Text(item.routeName))
                    .font(.subheadline)
                    .lineLimit(2)
                if let dur = item.duration {
                    Text(formatShortDuration(dur))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text(item.relativeTimestamp)
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - No Results

    private var noResultsView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No results for \"\(query)\"")
                .font(.headline)
            Text("Try searching for a route name, difficulty, tag, or friend's name.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(title)
            Text("(\(count))").foregroundStyle(.secondary)
        }
        .font(.caption.weight(.semibold))
        .textCase(nil)
    }

    private func suggestionRow(title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.medium).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    /// Returns a Text view with the matching portion bold
    private func highlightedText(_ text: String, query: String) -> Text {
        guard !query.isEmpty,
              let range = text.range(of: query, options: .caseInsensitive) else {
            return Text(text).foregroundStyle(Color.primary)
        }
        let before = String(text[text.startIndex..<range.lowerBound])
        let match  = String(text[range])
        let after  = String(text[range.upperBound..<text.endIndex])
        return Text(before).foregroundStyle(Color.primary)
            + Text(match).bold().foregroundStyle(Color.blue)
            + Text(after).foregroundStyle(Color.primary)
    }

    private func difficultyColor(_ d: Difficulty) -> Color {
        switch d {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    private func activityColor(_ type: ActivityType) -> Color {
        switch type {
        case .personalBestBeaten: return .yellow
        case .routeCompleted:     return .green
        case .friendRaced:        return .blue
        case .challengeAccepted:  return .orange
        case .challengeCompleted: return .purple
        }
    }
}

#Preview {
    NavigationStack {
        SearchView().environmentObject(AppState())
    }
}
