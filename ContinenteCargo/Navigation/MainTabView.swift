//
//  MainTabView.swift
//  ContinenteCargo
//
//  Bottom navigation with exactly three tabs: Home, Embarques, Alertas.
//

import SwiftUI

/// The three bottom tabs of the app.
enum MainTab: Hashable {
    case home
    case shipments
    case alerts
}

struct MainTabView: View {
    @Environment(AppSession.self) private var session
    // ViewModels live here so they survive tab switches without reloading.
    @State private var homeViewModel = HomeViewModel()
    @State private var shipmentsViewModel = ShipmentsViewModel()
    @State private var alertsViewModel = AlertsViewModel()

    var body: some View {
        @Bindable var session = session

        TabView(selection: $session.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: MainTab.home) {
                HomeView()
                    .environment(homeViewModel)
            }
            Tab("Embarques", systemImage: "shippingbox.fill", value: MainTab.shipments) {
                ShipmentsView()
                    .environment(shipmentsViewModel)
            }
            Tab("Alertas", systemImage: "bell.fill", value: MainTab.alerts) {
                AlertsView()
                    .environment(alertsViewModel)
            }
            .badge(homeViewModel.criticalCount)
        }
        .tint(CCColor.actionBlue)
    }
}

#Preview {
    MainTabView()
        .environment(AppSession())
}
