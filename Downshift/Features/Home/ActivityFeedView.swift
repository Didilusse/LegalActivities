
//
//  ActivityFeedView.swift
//  Downshift
//
//  Full chronological activity feed.
//

import SwiftUI

struct ActivityFeedView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var filterType: ActivityFeedFilter = .all

    enum ActivityFeedFilter: String, CaseIterable {
        case all = "All"
        case you = "You"
        case friends = "Friends"
        case pbs = "PBs"
    }

    var filteredFeed: [ActivityFeedItem] {
        switch filterType {
        case .all:
            return appState.activityFeed
        case .you:
            return appState.activityFeed.filter { $0.actorName == "You" }
        case .friends:
            return appState.activityFeed.filter { $0.type == .friendRaced }
        case .pbs:
            return appState.activityFeed.filter { $0.type == .personalBestBeaten }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            if filteredFeed.isEmpty {
                emptyView
            } else {
                List {
                    ForEach(filteredFeed) { item in
                        ActivityFeedRow(item: item)
                            .listRowBackground(Color(.secondarySystemBackground))
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Activity Feed")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            appState.refreshFriendsAndFeed()
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ActivityFeedFilter.allCases, id: \.self) { filter in
                    FilterChip(title: filter.rawValue, isSelected: filterType == filter) {
                        filterType = filter
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No activity here")
                .font(.headline)
            Text("Start racing routes to build your activity history.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

#Preview {
    NavigationStack {
        ActivityFeedView()
            .environmentObject(AppState())
    }
}
