//
//  CheckpointRow.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/13/25.
//

import SwiftUI
struct CheckpointRow: View {
    let checkpoint: LocationPin
    let number: Int
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "\(number).circle.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text("Checkpoint \(number)")
                    .fontWeight(.medium)
                Text("\(checkpoint.coordinate.latitude.formatted()), \(checkpoint.coordinate.longitude.formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
}
