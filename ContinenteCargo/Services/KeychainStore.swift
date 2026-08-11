//
//  KeychainStore.swift
//  ContinenteCargo
//
//  Minimal Keychain wrapper for persisting the Firebase auth session
//  securely across app launches. Tokens must never live in UserDefaults.
//

import Foundation
import Security

enum KeychainStore {

    private static let service = "com.continentecargo.auth"
    private static let account = "firebase-session"

    /// Persists the session, replacing any previous value.
    static func save(_ session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        // Delete-then-add keeps the logic simple and idempotent.
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        // Available after the first device unlock — required so the app
        // can restore the session on a cold launch.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    /// Loads the stored session, or nil when none exists.
    static func loadSession() -> AuthSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    /// Removes the stored session (sign out).
    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
