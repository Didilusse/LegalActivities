//
//  SaveRouteView.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/13/25.
//

import SwiftUI

struct SaveRouteView: View {
    @ObservedObject var vm: RouteCreationViewModel
    @Binding var isPresented: Bool
    @State private var routeName = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Route Name", text: $routeName)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                Button("Save Route") {
                    if vm.saveRoute(name: routeName) {
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(routeName.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Save Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
