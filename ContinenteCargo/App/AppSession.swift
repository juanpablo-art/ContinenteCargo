//
//  AppSession.swift
//  ContinenteCargo
//
//  App-wide session state. Owns the authenticated user, the Firebase
//  auth tokens and the shared data service, and drives root routing.
//  The session is persisted to the Keychain so the user stays signed in
//  across app switches and cold launches.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class AppSession {
    /// The signed-in user, or nil when logged out.
    var currentUser: User?

    /// Firebase tokens for the current session (idToken, refreshToken).
    /// Use `authSession?.idToken` as the bearer token for future API calls.
    private(set) var authSession: AuthSession?

    /// APNs device token received from the OS after push registration.
    var deviceToken: String?

    /// Backend client ID — resolved by the backend from the auth token.
    var clientID: Int? = nil

    /// Shipment ID received via push notification tap. Consumed by ShipmentsView to trigger navigation.
    var deepLinkShipmentID: Int? = nil

    /// Currently selected bottom tab. Lives here so any screen
    /// (e.g. Home's bell or "Ver todas") can switch tabs.
    var selectedTab: MainTab = .home

    /// Pending filter to apply when navigating to the Embarques tab from Home.
    /// ShipmentsView consumes and resets this to nil after applying.
    var shipmentFilter: ShipmentFilter? = nil

    /// Shared data service. Swap `MockShipmentService` for a real API client later.
    let service: ShipmentServing

    private let authService: AuthServicing

    var isAuthenticated: Bool { currentUser != nil }

    init(service: ShipmentServing? = nil, authService: AuthServicing? = nil) {
        self.service = service ?? MockShipmentService.shared
        self.authService = authService ?? FirebaseAuthService.shared

        // Restore a persisted session so a cold launch lands on Home,
        // not the login screen. Token freshness is handled afterwards
        // by `refreshSessionIfNeeded()`.
        if let stored = KeychainStore.loadSession() {
            authSession = stored
            currentUser = Self.user(from: stored)
        }
    }

    /// Stores the Firebase session (memory + Keychain) and derives the display user.
    /// Also registers the device for push notifications if a token is already available.
    func signIn(auth: AuthSession) {
        authSession = auth
        KeychainStore.save(auth)
        withAnimation(.smooth) {
            currentUser = Self.user(from: auth)
        }
        if let token = deviceToken {
            Task { await registerDevice(token: token, idToken: auth.idToken) }
        }
    }

    func signOut() {
        // Unregister device from push before clearing session.
        if let token = deviceToken, let idToken = authSession?.idToken {
            let savedToken = token
            let savedIdToken = idToken
            Task { try? await ContinenteAPIService.shared.unregisterDevice(token: savedToken, idToken: savedIdToken) }
        }
        authSession = nil
        KeychainStore.delete()
        withAnimation(.smooth) { currentUser = nil }
    }

    /// Called when the OS delivers the APNs device token.
    /// Registers with the backend if the user is already authenticated.
    func onDeviceTokenReceived(_ token: String) async {
        deviceToken = token
        guard let idToken = authSession?.idToken else { return }
        await registerDevice(token: token, idToken: idToken)
    }

    /// Renews the idToken when it has expired. Called on app launch and
    /// whenever the app returns to the foreground.
    /// - Offline: the local session is kept so the user isn't kicked out.
    /// - Token revoked/invalid: signs out, back to login.
    func refreshSessionIfNeeded() async {
        guard let current = authSession, current.isExpired else { return }
        do {
            let refreshed = try await authService.refresh(session: current)
            authSession = refreshed
            KeychainStore.save(refreshed)
        } catch let error as AuthError {
            if case .network = error { return }
            signOut()
        } catch {
            // Unknown failure: keep the session; the next refresh will retry.
        }
    }

    // MARK: - Push

    private func registerDevice(token: String, idToken: String) async {
        do {
            try await ContinenteAPIService.shared.registerDevice(token: token, idToken: idToken)
            print("📱 [Push] Device registered")
        } catch {
            print("📱 [Push] Register error: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private static func user(from auth: AuthSession) -> User {
        let name = auth.displayName.isEmpty
            ? auth.email.split(separator: "@").first.map { String($0).capitalizedFirst } ?? "Cliente"
            : auth.displayName
        return User(name: name, email: auth.email, company: "")
    }
}
