//
//  MetricCard.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/12/25.
//

import SwiftUI
struct MetricCard: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(.system(size: 24, weight: .bold))
            Text(label)
                .font(.caption)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}
