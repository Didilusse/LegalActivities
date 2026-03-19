
//
//  ContentView.swift
//  Downshift
//
//  Created by Adil Rahmani on 5/11/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var appState = AppState()

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .environmentObject(appState)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            FriendsView()
                .environmentObject(appState)
                .tabItem { Label("Social", systemImage: "person.2.fill") }
                .tag(1)

            NavigationStack {
                ProfileView()
                    .environmentObject(appState)
            }
            .tabItem { Label("Profile", systemImage: "person.circle.fill") }
            .tag(2)
        }
    }
}

#Preview {
    ContentView()
}
