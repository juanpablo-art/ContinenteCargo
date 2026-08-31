//
//  RegisterViewModel.swift
//  ContinenteCargo
//
//  El registro solo recopila los datos del solicitante y notifica al equipo.
//  La empresa crea y activa la cuenta manualmente desde Firebase Console.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class RegisterViewModel {
    var name: String = ""
    var email: String = ""
    var phone: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !phone.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func requestAccess(onSuccess: () -> Void) async {
        guard canSubmit else {
            errorMessage = "Completa todos los campos."
            return
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = "Ingresa un correo electrónico válido."
            return
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespaces)

        await RegistrationNotifierService.shared.notifyNewRegistration(
            name: trimmedName,
            email: trimmedEmail,
            phone: trimmedPhone
        )

        onSuccess()
    }
}
