
//
//  ProfileView.swift
//  Downshift
//
//  User profile, stats summary, garage, and settings.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var showGarage = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileHeader
                quickActionsSection
                statsGrid
                garagePreviewSection
                personalBestsSection
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showGarage) {
            MyGarageView()
                .environmentObject(appState)
        }
        .onAppear {
            appState.updateUserStats()
        }
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile card with gradient background
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.6),
                        Color.purple.opacity(0.4)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                VStack(spacing: 16) {
                    // Avatar
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: appState.userProfile.avatarSystemName)
                            .font(.system(size: 56))
                            .foregroundStyle(.white)
                            .frame(width: 100, height: 100)
                            .background(.white.opacity(0.2))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 3)
                            )

                        Button {
                            showEditProfile = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                    }

                    // Name and info
                    VStack(spacing: 6) {
                        Text(appState.userProfile.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        
                        if let car = appState.userProfile.primaryCar {
                            HStack(spacing: 4) {
                                Image(systemName: "car.fill")
                                    .font(.caption)
                                Text(car.displayName)
                                    .font(.caption)
                            }
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    
                    // Member since badge
                    HStack(spacing: 16) {
                        VStack {
                            Text("\(appState.userProfile.totalRaces)")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Races")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        
                        Divider()
                            .frame(height: 30)
                            .background(.white.opacity(0.3))
                        
                        VStack {
                            Text("\(appState.savedRoutes.count)")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Routes")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        
                        Divider()
                            .frame(height: 30)
                            .background(.white.opacity(0.3))
                        
                        VStack {
                            Text("\(appState.userProfile.garage.count)")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Cars")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            quickActionButton(
                title: "Edit Profile",
                icon: "person.fill",
                color: .blue
            ) {
                showEditProfile = true
            }
            
            quickActionButton(
                title: "My Garage",
                icon: "car.fill",
                color: .orange
            ) {
                showGarage = true
            }
            
            quickActionButton(
                title: "Settings",
                icon: "gearshape.fill",
                color: .gray
            ) {
                showSettings = true
            }
        }
        .padding(.horizontal)
    }
    
    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        let units = appState.userProfile.unitPreference

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.blue)
                Text("Your Stats")
                    .font(.headline)
            }
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
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Spacer()
            
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // MARK: - Garage Preview Section
    private var garagePreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "car.2.fill")
                    .foregroundStyle(.orange)
                Text("My Garage")
                    .font(.headline)
                Spacer()
                Button {
                    showGarage = true
                } label: {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            
            if appState.userProfile.garage.isEmpty {
                // Empty state
                Button {
                    showGarage = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundStyle(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Your First Car")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Text("Show off what you drive")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            } else {
                // Car cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(appState.userProfile.garage) { car in
                            carPreviewCard(car)
                        }
                        
                        // Add car button
                        Button {
                            showGarage = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.orange)
                                Text("Add Car")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 100, height: 100)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    private func carPreviewCard(_ car: Car) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Spacer()
                if car.isPrimary {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 2) {
                Text(car.make)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(car.model)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text("\(car.year)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .frame(width: 120, height: 120)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Personal Bests
    private var personalBestsSection: some View {
        Group {
            if !appState.userProfile.personalBests.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundStyle(.yellow)
                        Text("Personal Bests")
                            .font(.headline)
                    }
                    .padding(.horizontal)

                    VStack(spacing: 0) {
                        ForEach(Array(appState.userProfile.personalBests.sorted(by: { $0.value < $1.value }).prefix(5).enumerated()), id: \.element.key) { index, item in
                            let routeName = appState.savedRoutes.first(where: { $0.id.uuidString == item.key })?.name ?? "Unknown Route"
                            
                            HStack(spacing: 12) {
                                // Rank badge
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(index == 0 ? Color.yellow : index == 1 ? Color.gray : index == 2 ? Color.orange.opacity(0.7) : Color.gray.opacity(0.5))
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(routeName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Text(formatShortDuration(item.value))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.blue)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            
                            if index < min(appState.userProfile.personalBests.count, 5) - 1 {
                                Divider().padding(.horizontal)
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // Units Section
                Section {
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
                            Text("Metric").tag(UnitPreference.metric)
                            Text("Imperial").tag(UnitPreference.imperial)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }
                } header: {
                    Text("Preferences")
                }
                
                // Audio & Haptics Section
                Section {
                    Toggle(isOn: Binding(
                        get: { appState.userProfile.soundEnabled },
                        set: { newValue in
                            appState.userProfile.soundEnabled = newValue
                            appState.saveProfile()
                        }
                    )) {
                        Label("Sound Effects", systemImage: "speaker.wave.2.fill")
                    }
                    
                    Toggle(isOn: Binding(
                        get: { appState.userProfile.hapticEnabled },
                        set: { newValue in
                            appState.userProfile.hapticEnabled = newValue
                            appState.saveProfile()
                        }
                    )) {
                        Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                    }
                } header: {
                    Text("Audio & Haptics")
                }
                
                // Racing Section
                Section {
                    Toggle(isOn: Binding(
                        get: { appState.userProfile.rallyDirectionsEnabled },
                        set: { newValue in
                            appState.userProfile.rallyDirectionsEnabled = newValue
                            appState.saveProfile()
                        }
                    )) {
                        Label("Rally Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    }
                } header: {
                    Text("Racing")
                } footer: {
                    Text("Enable rally-style pace notes during races (e.g., \"Left 3 over crest\")")
                }
                
                // About Section
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - My Garage View
struct MyGarageView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAddCar = false
    @State private var carToEdit: Car? = nil
    
    var body: some View {
        NavigationStack {
            Group {
                if appState.userProfile.garage.isEmpty {
                    emptyGarageView
                } else {
                    garageList
                }
            }
            .navigationTitle("My Garage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddCar = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddCar) {
                AddEditCarView(car: nil)
                    .environmentObject(appState)
            }
            .sheet(item: $carToEdit) { car in
                AddEditCarView(car: car)
                    .environmentObject(appState)
            }
        }
    }
    
    private var emptyGarageView: some View {
        VStack(spacing: 20) {
            Image(systemName: "car.2.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("Your Garage is Empty")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Add the cars you drive to show them on your profile")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button {
                showAddCar = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Your First Car")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.orange)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var garageList: some View {
        List {
            ForEach(appState.userProfile.garage) { car in
                carRow(car)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        carToEdit = car
                    }
            }
            .onDelete(perform: deleteCar)
        }
        .listStyle(.insetGrouped)
    }
    
    private func carRow(_ car: Car) -> some View {
        HStack(spacing: 14) {
            // Car icon
            Image(systemName: "car.fill")
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 44, height: 44)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Car info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(car.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if car.isPrimary {
                        Text("Primary")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                
                Text(car.color)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
    
    private func deleteCar(at offsets: IndexSet) {
        appState.userProfile.garage.remove(atOffsets: offsets)
        // If we deleted the primary car, make the first car primary
        if !appState.userProfile.garage.isEmpty && !appState.userProfile.garage.contains(where: { $0.isPrimary }) {
            appState.userProfile.garage[0].isPrimary = true
        }
        appState.saveProfile()
    }
}

// MARK: - Add/Edit Car View
struct AddEditCarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    let car: Car?
    
    @State private var make: String = ""
    @State private var customMake: String = ""
    @State private var model: String = ""
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var color: String = "Silver"
    @State private var customColor: String = ""
    @State private var isPrimary: Bool = false
    
    private var isEditing: Bool { car != nil }
    
    private var yearRange: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((1950...(currentYear + 1)).reversed())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Make picker
                    Picker("Make", selection: $make) {
                        Text("Select Make").tag("")
                        ForEach(CarMake.allCases, id: \.self) { carMake in
                            Text(carMake.rawValue).tag(carMake.rawValue)
                        }
                    }
                    
                    if make == CarMake.other.rawValue {
                        TextField("Enter Make", text: $customMake)
                    }
                    
                    // Model
                    TextField("Model", text: $model)
                    
                    // Year picker
                    Picker("Year", selection: $year) {
                        ForEach(yearRange, id: \.self) { y in
                            Text("\(y)").tag(y)
                        }
                    }
                } header: {
                    Text("Vehicle Info")
                }
                
                Section {
                    // Color picker
                    Picker("Color", selection: $color) {
                        ForEach(CarColor.allCases, id: \.self) { carColor in
                            Text(carColor.rawValue).tag(carColor.rawValue)
                        }
                    }
                    
                    if color == CarColor.other.rawValue {
                        TextField("Enter Color", text: $customColor)
                    }
                } header: {
                    Text("Appearance")
                }
                
                Section {
                    Toggle("Set as Primary Car", isOn: $isPrimary)
                } footer: {
                    Text("Your primary car will be displayed on your profile")
                }
                
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            deleteCar()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Car")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Car" : "Add Car")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCar()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let car = car {
                    // Check if make is in our list
                    if CarMake.allCases.contains(where: { $0.rawValue == car.make }) {
                        make = car.make
                    } else {
                        make = CarMake.other.rawValue
                        customMake = car.make
                    }
                    model = car.model
                    year = car.year
                    // Check if color is in our list
                    if CarColor.allCases.contains(where: { $0.rawValue == car.color }) {
                        color = car.color
                    } else {
                        color = CarColor.other.rawValue
                        customColor = car.color
                    }
                    isPrimary = car.isPrimary
                }
            }
        }
    }
    
    private var isValid: Bool {
        let finalMake = make == CarMake.other.rawValue ? customMake : make
        return !finalMake.trimmingCharacters(in: .whitespaces).isEmpty &&
               !model.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func saveCar() {
        let finalMake = make == CarMake.other.rawValue ? customMake : make
        let finalColor = color == CarColor.other.rawValue ? customColor : color
        
        // If setting as primary, remove primary from others
        if isPrimary {
            for i in appState.userProfile.garage.indices {
                appState.userProfile.garage[i].isPrimary = false
            }
        }
        
        if let existingCar = car {
            // Update existing car
            if let index = appState.userProfile.garage.firstIndex(where: { $0.id == existingCar.id }) {
                appState.userProfile.garage[index].make = finalMake
                appState.userProfile.garage[index].model = model
                appState.userProfile.garage[index].year = year
                appState.userProfile.garage[index].color = finalColor
                appState.userProfile.garage[index].isPrimary = isPrimary
            }
        } else {
            // Add new car
            let newCar = Car(
                make: finalMake,
                model: model,
                year: year,
                color: finalColor,
                isPrimary: isPrimary || appState.userProfile.garage.isEmpty // First car is always primary
            )
            appState.userProfile.garage.append(newCar)
        }
        
        appState.saveProfile()
        dismiss()
    }
    
    private func deleteCar() {
        if let existingCar = car {
            appState.userProfile.garage.removeAll { $0.id == existingCar.id }
            // If we deleted the primary car, make the first car primary
            if !appState.userProfile.garage.isEmpty && !appState.userProfile.garage.contains(where: { $0.isPrimary }) {
                appState.userProfile.garage[0].isPrimary = true
            }
            appState.saveProfile()
        }
        dismiss()
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
