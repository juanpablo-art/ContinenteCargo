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
    @State private var showSplash = true

    var body: some View {
        ZStack {
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

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .environment(session)
        // Run session init and a minimum splash duration concurrently;
        // the splash stays until both finish so the UI is never jarring.
        .task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await session.refreshSessionIfNeeded() }
                group.addTask { try? await Task.sleep(for: .milliseconds(1500)) }
            }
            withAnimation(.easeInOut(duration: 0.35)) { showSplash = false }
        }
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
        // Deep-link to a shipment when the user taps a push notification.
        // FCM flattens the `data` block into userInfo; shippingId arrives as a String.
        .onReceive(NotificationCenter.default.publisher(for: .pushNotificationTapped)) { notification in
            guard let userInfo = notification.userInfo,
                  let raw = userInfo["shippingId"] as? String,
                  let id = Int(raw) else { return }
            session.selectedTab = .shipments
            session.deepLinkShipmentID = id
        }
    }
}

#Preview {
    RootView()
}
