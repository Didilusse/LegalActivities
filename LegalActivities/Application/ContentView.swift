//
//  ContentView.swift
//  LegalActivities
//
//  Created by Adil Rahmani on 5/11/25.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @StateObject var locationManager = LocationManager()
    @StateObject var routeVM = RouteCreationViewModel()
    @State private var showingRaceView = false
    
    var body: some View {
        RoutesListView()
    }
}
#Preview {
    ContentView()
}
