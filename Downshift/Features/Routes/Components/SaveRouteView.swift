//
//  SaveRouteView.swift
//  Downshift
//

import SwiftUI

struct SaveRouteView: View {
    @ObservedObject var vm: RouteCreationViewModel
    @Binding var isPresented: Bool
    var onSaved: (String) -> Void = { _ in }

    @State private var routeName = ""
    @State private var routeLocation = ""
    @State private var selectedDifficulty: Difficulty = .medium
    @State private var tagInput = ""
    @State private var tags: [String] = []
    @FocusState private var nameFieldFocused: Bool

    private let suggestedTags = ["Urban", "Highway", "Scenic", "Mountain", "Coastal", "Track", "Sprint"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Route summary card
                    routeSummaryCard

                    // Name field
                    nameSection
                    
                    // Location field
                    locationSection

                    // Difficulty
                    difficultySection

                    // Tags
                    tagsSection
                }
                .padding()
            }
            .navigationTitle("Save Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRoute() }
                        .fontWeight(.semibold)
                        .disabled(routeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { nameFieldFocused = true }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Route summary card
    private var routeSummaryCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 52, height: 52)
                .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text("Route Summary")
                    .font(.headline)
                HStack(spacing: 12) {
                    Label("\(vm.annotations.count) points", systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("\(vm.checkpoints.count) checkpoints", systemImage: "flag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Name
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Route Name")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            TextField("e.g. Downtown Loop", text: $routeName)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .focused($nameFieldFocused)
                .submitLabel(.done)
        }
    }
    
    // MARK: - Location
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Location")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                
                Text("(Optional)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            TextField("e.g. San Francisco, CA", text: $routeLocation)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .submitLabel(.done)
            
            Text("Add a town or city to help users find routes near them")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Difficulty
    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Difficulty")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(Difficulty.allCases, id: \.self) { diff in
                    Button {
                        selectedDifficulty = diff
                    } label: {
                        Text(diff.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(
                                selectedDifficulty == diff
                                    ? difficultyColor(diff)
                                    : Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .foregroundStyle(selectedDifficulty == diff ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: selectedDifficulty)
                }
            }
        }
    }

    // MARK: - Tags
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tags")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            // Active tags
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag)
                                .font(.caption)
                                .fontWeight(.medium)
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                        .foregroundStyle(.blue)
                    }
                }
            }

            // Suggested tags
            FlowLayout(spacing: 8) {
                ForEach(suggestedTags.filter { !tags.contains($0) }, id: \.self) { tag in
                    Button {
                        if !tags.contains(tag) { tags.append(tag) }
                    } label: {
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.tertiarySystemBackground), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func difficultyColor(_ difficulty: Difficulty) -> Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    private func saveRoute() {
        let name = routeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let location = routeLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        if vm.saveRoute(name: name, difficulty: selectedDifficulty, tags: tags, location: location.isEmpty ? nil : location) {
            isPresented = false
            onSaved(name)
        }
    }
}

// MARK: - Simple Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    SaveRouteView(vm: RouteCreationViewModel(), isPresented: .constant(true))
}

