//
//  PointSelectionButton.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/12/25.
//

import SwiftUI

struct PointSelectionButton: View {
    let type: LocationPin.PointType
    @Binding var selectedType: LocationPin.PointType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: type.icon)
                .foregroundColor(selectedType == type ? .white : type.markerColor)
                .padding()
                .background(selectedType == type ? type.markerColor : Color.clear)
                .clipShape(Circle())
        }
    }
}
