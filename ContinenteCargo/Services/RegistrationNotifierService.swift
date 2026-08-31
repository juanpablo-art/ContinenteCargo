//
//  RegistrationNotifierService.swift
//  ContinenteCargo
//
//  Sends two emails via Brevo when a new user registers:
//  1. Notificación al admin (JuanPablo@continentecargo.com) con los datos del usuario.
//  2. Bienvenida al nuevo usuario con mensaje de confirmación.
//

import Foundation

private enum RegistrationNotifierConfig {
    static let apiKey = Bundle.main.object(forInfoDictionaryKey: "BrevoAPIKey") as? String ?? ""
    static let adminEmail = "JuanPablo@continentecargo.com"
    static let senderEmail = "noreply@continentecargo.com"
    static let senderName = "Continente Cargo"
    static let url = URL(string: "https://api.brevo.com/v3/smtp/email")!
}

final class RegistrationNotifierService {
    static let shared = RegistrationNotifierService()

    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func notifyNewRegistration(name: String, email: String, phone: String) async {
        await sendAdminNotification(name: name, email: email, phone: phone)
        await sendWelcomeEmail(to: email, name: name)
    }

    // MARK: - Correo al admin

    private func sendAdminNotification(name: String, email: String, phone: String) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm 'hrs'"
        formatter.locale = Locale(identifier: "es_MX")
        formatter.timeZone = TimeZone(identifier: "America/Mexico_City")
        let dateString = formatter.string(from: Date())

        let html = """
        <div style="font-family: Arial, sans-serif; max-width: 520px; margin: 0 auto; color: #222;">
          <h2 style="color: #1a1a2e; margin-bottom: 16px;">Nuevo usuario registrado</h2>
          <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
            <tr>
              <td style="padding: 10px 8px; font-weight: bold; color: #555; width: 40%;">Nombre completo</td>
              <td style="padding: 10px 8px;">\(name)</td>
            </tr>
            <tr style="background: #f5f5f5;">
              <td style="padding: 10px 8px; font-weight: bold; color: #555;">Correo electrónico</td>
              <td style="padding: 10px 8px;">\(email)</td>
            </tr>
            <tr>
              <td style="padding: 10px 8px; font-weight: bold; color: #555;">Teléfono</td>
              <td style="padding: 10px 8px;">\(phone)</td>
            </tr>
            <tr style="background: #f5f5f5;">
              <td style="padding: 10px 8px; font-weight: bold; color: #555;">Fecha de registro</td>
              <td style="padding: 10px 8px;">\(dateString)</td>
            </tr>
          </table>
          <p style="margin-top: 24px; font-size: 12px; color: #999;">
            Enviado automáticamente por Continente Cargo App.
          </p>
        </div>
        """

        await sendEmail(
            to: RegistrationNotifierConfig.adminEmail,
            subject: "Nuevo usuario registrado: \(name)",
            html: html
        )
    }

    // MARK: - Correo de bienvenida al usuario

    private func sendWelcomeEmail(to email: String, name: String) async {
        let firstName = name.components(separatedBy: " ").first ?? name

        let html = """
        <div style="font-family: Arial, sans-serif; max-width: 520px; margin: 0 auto; color: #222;">
          <img src="https://continentecargo.com/logo.png" alt="Continente Cargo" style="height: 48px; margin-bottom: 24px;" />
          <h2 style="color: #1a1a2e;">¡Gracias por registrarte, \(firstName)!</h2>
          <p style="font-size: 15px; line-height: 1.6; color: #444;">
            Tu cuenta en <strong>Continente Cargo</strong> ha sido creada exitosamente.<br><br>
            En seguida un ejecutivo se pondrá en contacto contigo para darte la bienvenida y orientarte en el uso de la plataforma.
          </p>
          <p style="margin-top: 32px; font-size: 13px; color: #999;">
            Continente Cargo — Tu operación logística en un solo lugar.
          </p>
        </div>
        """

        await sendEmail(
            to: email,
            subject: "¡Bienvenido a Continente Cargo!",
            html: html
        )
    }

    // MARK: - Envío base

    private func sendEmail(to recipient: String, subject: String, html: String) async {
        struct Sender: Encodable { let name: String; let email: String }
        struct Recipient: Encodable { let email: String }
        struct EmailRequest: Encodable {
            let sender: Sender
            let to: [Recipient]
            let subject: String
            let htmlContent: String
        }

        let payload = EmailRequest(
            sender: Sender(name: RegistrationNotifierConfig.senderName,
                           email: RegistrationNotifierConfig.senderEmail),
            to: [Recipient(email: recipient)],
            subject: subject,
            htmlContent: html
        )

        var request = URLRequest(url: RegistrationNotifierConfig.url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(RegistrationNotifierConfig.apiKey, forHTTPHeaderField: "api-key")
        request.httpBody = try? JSONEncoder().encode(payload)

        do {
            let (data, response) = try await urlSession.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            #if DEBUG
            let body = String(data: data, encoding: .utf8) ?? "(vacío)"
            print("📧 Brevo → \(recipient) | HTTP \(statusCode) | \(body)")
            #endif
        } catch {
            #if DEBUG
            print("📧 Brevo error → \(recipient): \(error)")
            #endif
        }
    }
}
