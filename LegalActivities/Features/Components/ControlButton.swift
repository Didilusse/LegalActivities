//
//  ControlButton.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/12/25.
//

import SwiftUI
struct ControlButton: View {
    let icon: String
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack { 
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption)
            }
            .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            .frame(minWidth: 80) // Give some min width
            .background(isSelected ? color.opacity(0.25) : Color.clear)
            .foregroundColor(isSelected ? color : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? color : Color.gray.opacity(0.5), lineWidth: 1.5))
        }
    }
}
