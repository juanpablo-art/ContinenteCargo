//
//  LoginViewModel.swift
//  ContinenteCargo
//

import SwiftUI
import Observation

@Observable
@MainActor
final class LoginViewModel {
    var email: String = ""
    var password: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    /// The button is enabled once both fields have content.
    var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    private let authService: AuthServicing

    init(authService: AuthServicing) {
        self.authService = authService
    }

    /// Authenticates against Firebase. On success hands the session to `onSuccess`.
    func signIn(onSuccess: (AuthSession) -> Void) async {
        guard canSubmit else {
            errorMessage = "Ingresa tu correo y contraseña."
            return
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let session = try await authService.signIn(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
            onSuccess(session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
