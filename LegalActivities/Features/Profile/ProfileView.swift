
//
//  ProfileView.swift
//  LegalActivities
//
//  User profile, stats summary, and settings.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showEditProfile = false
    @State private var editedName: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeader
                statsGrid
                personalBestsSection
                settingsSection
            }
            .padding(.vertical)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(appState)
        }
        .onAppear {
            appState.updateUserStats()
        }
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: appState.userProfile.avatarSystemName)
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                    .frame(width: 100, height: 100)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())

                Button {
                    showEditProfile = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                }
            }

            Text(appState.userProfile.name)
                .font(.title2)
                .fontWeight(.bold)

            Button("Edit Profile") {
                showEditProfile = true
            }
            .font(.subheadline)
            .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        let units = appState.userProfile.unitPreference

        return VStack(alignment: .leading, spacing: 10) {
            Text("Your Stats")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statsCard(value: "\(appState.userProfile.totalRaces)", label: "Total Races", icon: "flag.checkered", color: .blue)
                statsCard(value: units.formatDistance(appState.userProfile.totalDistance), label: "Total Distance", icon: "road.lanes", color: .green)
                statsCard(value: formatDuration(appState.userProfile.totalTime), label: "Total Time", icon: "clock.fill", color: .orange)
                statsCard(value: units.formatSpeed(appState.userProfile.bestAvgSpeed), label: "Best Avg Speed", icon: "speedometer", color: .purple)
            }
            .padding(.horizontal)
        }
    }

    private func statsCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Personal Bests
    private var personalBestsSection: some View {
        Group {
            if !appState.userProfile.personalBests.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Personal Bests")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(spacing: 0) {
                        ForEach(Array(appState.userProfile.personalBests.sorted(by: { $0.value < $1.value }).prefix(5)), id: \.key) { routeIdStr, time in
                            let routeName = appState.savedRoutes.first(where: { $0.id.uuidString == routeIdStr })?.name ?? "Unknown Route"
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
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Settings
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                // Unit preference
                settingRow {
                    HStack {
                        Label("Units", systemImage: "ruler")
                        Spacer()
                        Picker("Units", selection: Binding(
                            get: { appState.userProfile.unitPreference },
                            set: { newValue in
                                appState.userProfile.unitPreference = newValue
                                appState.saveProfile()
                            }
                        )) {
                            ForEach(UnitPreference.allCases, id: \.self) { pref in
                                Text(pref == .metric ? "Metric" : "Imperial").tag(pref)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }
                }

                Divider().padding(.leading, 52)

                // Sound
                settingRow {
                    Toggle(isOn: Binding(
                        get: { appState.userProfile.soundEnabled },
                        set: { newValue in
                            appState.userProfile.soundEnabled = newValue
                            appState.saveProfile()
                        }
                    )) {
                        Label("Sound Effects", systemImage: "speaker.wave.2.fill")
                    }
                }

                Divider().padding(.leading, 52)

                // Haptics
                settingRow {
                    Toggle(isOn: Binding(
                        get: { appState.userProfile.hapticEnabled },
                        set: { newValue in
                            appState.userProfile.hapticEnabled = newValue
                            appState.saveProfile()
                        }
                    )) {
                        Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private func settingRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal)
            .padding(.vertical, 12)
    }
}

// MARK: - Edit Profile Sheet
struct EditProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedAvatar: String = "person.circle.fill"

    let availableAvatars = [
        "person.circle.fill", "figure.run", "car.fill",
        "bolt.circle.fill", "star.circle.fill", "flame.circle.fill",
        "wind.circle.fill", "tortoise.fill", "hare.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Your name", text: $name)
                }

                Section("Avatar") {
                    // Use explicit rows to avoid the LazyVGrid+Form tap-hijacking bug
                    let columns = 5
                    let rows = (availableAvatars.count + columns - 1) / columns
                    VStack(spacing: 14) {
                        ForEach(0..<rows, id: \.self) { row in
                            HStack(spacing: 14) {
                                ForEach(0..<columns, id: \.self) { col in
                                    let index = row * columns + col
                                    if index < availableAvatars.count {
                                        let avatar = availableAvatars[index]
                                        Button {
                                            selectedAvatar = avatar
                                        } label: {
                                            Image(systemName: avatar)
                                                .font(.title)
                                                .foregroundStyle(selectedAvatar == avatar ? .white : .blue)
                                                .frame(width: 52, height: 52)
                                                .background(selectedAvatar == avatar ? Color.blue : Color.blue.opacity(0.1))
                                                .clipShape(Circle())
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        Spacer().frame(width: 52, height: 52)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            appState.userProfile.name = trimmed
                        }
                        appState.userProfile.avatarSystemName = selectedAvatar
                        appState.saveProfile()
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = appState.userProfile.name
                selectedAvatar = appState.userProfile.avatarSystemName
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AppState())
    }
}
