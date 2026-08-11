//
//  RegisterViewModel.swift
//  ContinenteCargo
//

import SwiftUI
import Observation

@Observable
@MainActor
final class RegisterViewModel {
    var name: String = ""
    var email: String = ""
    var password: String = ""
    var confirmPassword: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    /// The button is enabled once every field has content.
    var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && !confirmPassword.isEmpty
    }

    private let authService: AuthServicing

    init(authService: AuthServicing) {
        self.authService = authService
    }

    /// Creates the account in Firebase. On success hands the session to `onSuccess`.
    func signUp(onSuccess: (AuthSession) -> Void) async {
        guard canSubmit else {
            errorMessage = "Completa todos los campos."
            return
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = "Ingresa un correo electrónico válido."
            return
        }
        guard password.count >= 6 else {
            errorMessage = AuthError.weakPassword.errorDescription
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Las contraseñas no coinciden."
            return
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let session = try await authService.signUp(
                name: name.trimmingCharacters(in: .whitespaces),
                email: trimmedEmail,
                password: password
            )
            onSuccess(session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
