//
//  RootView.swift
//  ContinenteCargo
//
//  Top-level view that routes between authentication and the main app
//  based on the session state.
//

import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var session = AppSession()

    var body: some View {
        Group {
            if session.isAuthenticated {
                MainTabView()
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .environment(session)
        // Renew the token on launch and whenever the app returns
        // to the foreground after being backgrounded.
        .task { await session.refreshSessionIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await session.refreshSessionIfNeeded() }
            }
        }
        // Forward the APNs device token to the session so it can
        // register the device with the backend.
        .onReceive(NotificationCenter.default.publisher(for: .apnsDeviceToken)) { notification in
            guard let token = notification.userInfo?["token"] as? String else { return }
            Task { await session.onDeviceTokenReceived(token) }
        }
    }
}

#Preview {
    RootView()
}
