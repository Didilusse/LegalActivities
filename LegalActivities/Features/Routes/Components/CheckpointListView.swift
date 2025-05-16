//
//  CheckpointListView.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/13/25.
//

import SwiftUI
import MapKit
struct CheckpointListView: View {
    @ObservedObject var vm: RouteCreationViewModel
    @Binding var mapView: MKMapView
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Checkpoints")
                    .font(.headline)
                Text("(\(vm.checkpoints.count))")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            
            List {
                ForEach(vm.checkpoints, id: \.id) { checkpoint in
                    CheckpointRow(
                        checkpoint: checkpoint,
                        number: vm.getCheckpointNumber(for: checkpoint) ?? 0,
                        isSelected: vm.selectedAnnotation?.id == checkpoint.id
                    )
                    .onTapGesture {
                        vm.selectAnnotation(checkpoint)
                        centerOnCheckpoint(checkpoint)
                    }
                }
                .onDelete(perform: vm.deleteCheckpointsFromList)
                .onMove(perform: vm.moveCheckpointInList)
            }
            .listStyle(.plain)
            .frame(height: min(CGFloat(vm.checkpoints.count * 60), 300))
        }
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(radius: 5)
        .padding()
    }
    
    private func centerOnCheckpoint(_ checkpoint: LocationPin) {
        let region = MKCoordinateRegion(
            center: checkpoint.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )
        mapView.setRegion(region, animated: true)
    }
}
