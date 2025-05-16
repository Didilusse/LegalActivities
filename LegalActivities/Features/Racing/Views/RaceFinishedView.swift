//
//  RaceFinishedView.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/16/25.
//


import SwiftUI

struct RaceFinishedView: View {
    let raceResult: RaceResult
    let routeName: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView { // Embed in NavigationView for a toolbar with a Done button
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("🎉 Race Finished! 🎉")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom)

                    Text(routeName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.bottom, 5)

                    StatisticRow(label: "Total Time:", value: formatTimeDisplay(raceResult.totalDuration))
                    StatisticRow(label: "Total Distance:", value: String(format: "%.2f km", raceResult.totalDistance / 1000))
                    StatisticRow(label: "Average Speed:", value: String(format: "%.1f km/h", raceResult.averageSpeed * 3.6))

                    if !raceResult.lapDurations.isEmpty {
                        Text("Segment Times:")
                            .font(.title3)
                            .fontWeight(.medium)
                            .padding(.top)
                        
                        ForEach(raceResult.lapDurations.indices, id: \.self) { index in
                            let segmentLabel = (index + 1) < (raceResult.lapDurations.count) ? "Segment \(index + 1) (to CP\(index + 1))" : "Segment \(index + 1) (to Finish)"
                            StatisticRow(label: segmentLabel + ":", value: formatTimeDisplay(raceResult.lapDurations[index]))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Race Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatTimeDisplay(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: seconds) ?? "00:00:00"
    }
}

struct StatisticRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                    .font(.headline)
                Spacer()
                Text(value)
                    .font(.body)
                    .monospacedDigit()
            }
            Divider()
        }
    }
}

// Preview
struct RaceFinishedView_Previews: PreviewProvider {
    static var previews: some View {
        RaceFinishedView(
            raceResult: RaceResult(
                totalDuration: 1234.5, // about 20 mins
                lapDurations: [300.2, 310.5, 305.8, 318.0],
                totalDistance: 5025.0, // 5 km
                averageSpeed: 4.07 // m/s
            ),
            routeName: "City Park Loop"
        )
    }
}