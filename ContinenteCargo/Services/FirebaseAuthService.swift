//
//  FirebaseAuthService.swift
//  ContinenteCargo
//
//  Email/password authentication against Firebase Identity Toolkit (REST).
//  No Firebase SDK required — a plain URLSession client keeps the app light.
//

import Foundation

// MARK: - Configuration

/// Firebase project configuration.
/// Note: Firebase web API keys identify the project and are safe to ship
/// in the client; access control is enforced server-side.
enum FirebaseConfig {
    static let apiKey = "AIzaSyAWkOhk9fyDLNdzLPxuptjMeqcRbq6qEXQ"
    static let projectID = "cc-app-live"

    static var signInURL: URL {
        URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(apiKey)")!
    }

    static var signUpURL: URL {
        URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(apiKey)")!
    }

    static var updateProfileURL: URL {
        URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:update?key=\(apiKey)")!
    }

    static var refreshTokenURL: URL {
        URL(string: "https://securetoken.googleapis.com/v1/token?key=\(apiKey)")!
    }
}

// MARK: - Models

/// Tokens and identity returned by a successful Firebase sign-in.
/// Codable so it can be persisted to the Keychain across launches.
struct AuthSession: Codable {
    let localID: String
    let email: String
    let displayName: String
    let idToken: String
    let refreshToken: String
    /// Absolute moment the `idToken` expires.
    let expiresAt: Date

    var isExpired: Bool { Date() >= expiresAt }
}

/// Contract for the authentication provider.
protocol AuthServicing {
    func signIn(email: String, password: String) async throws -> AuthSession
    func signUp(name: String, email: String, password: String) async throws -> AuthSession
    func refresh(session: AuthSession) async throws -> AuthSession
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case invalidCredentials
    case userDisabled
    case tooManyAttempts
    case emailInUse
    case weakPassword
    case network
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Correo o contraseña incorrectos."
        case .userDisabled:
            return "Esta cuenta ha sido deshabilitada. Contacta a tu ejecutivo."
        case .tooManyAttempts:
            return "Demasiados intentos. Espera unos minutos e inténtalo de nuevo."
        case .emailInUse:
            return "Este correo ya está registrado. Inicia sesión."
        case .weakPassword:
            return "La contraseña debe tener al menos 6 caracteres."
        case .network:
            return "Sin conexión. Revisa tu internet e inténtalo de nuevo."
        case .server(let message):
            return "No se pudo completar la operación. (\(message))"
        }
    }
}

// MARK: - Service

final class FirebaseAuthService: AuthServicing {

    static let shared = FirebaseAuthService()

    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: Sign in

    func signIn(email: String, password: String) async throws -> AuthSession {
        struct SignInRequest: Encodable {
            let email: String
            let password: String
            let returnSecureToken = true
        }

        struct SignInResponse: Decodable {
            let localId: String
            let email: String
            let displayName: String
            let idToken: String
            let refreshToken: String
            let expiresIn: String
        }

        let response: SignInResponse = try await post(
            to: FirebaseConfig.signInURL,
            body: SignInRequest(email: email, password: password)
        )

        return AuthSession(
            localID: response.localId,
            email: response.email,
            displayName: response.displayName,
            idToken: response.idToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn) ?? 3600)
        )
    }

    // MARK: Sign up

    func signUp(name: String, email: String, password: String) async throws -> AuthSession {
        struct SignUpRequest: Encodable {
            let email: String
            let password: String
            let returnSecureToken = true
        }

        struct SignUpResponse: Decodable {
            let localId: String
            let email: String
            let idToken: String
            let refreshToken: String
            let expiresIn: String
        }

        let response: SignUpResponse = try await post(
            to: FirebaseConfig.signUpURL,
            body: SignUpRequest(email: email, password: password)
        )

        // Store the display name on the Firebase profile. Best effort:
        // the account already exists, so a failure here shouldn't fail sign-up.
        struct UpdateRequest: Encodable {
            let idToken: String
            let displayName: String
            let returnSecureToken = false
        }
        struct UpdateResponse: Decodable {
            let displayName: String?
        }
        let displayName = name.trimmingCharacters(in: .whitespaces)
        if !displayName.isEmpty {
            let _: UpdateResponse? = try? await post(
                to: FirebaseConfig.updateProfileURL,
                body: UpdateRequest(idToken: response.idToken, displayName: displayName)
            )
        }

        return AuthSession(
            localID: response.localId,
            email: response.email,
            displayName: displayName,
            idToken: response.idToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn) ?? 3600)
        )
    }

    // MARK: Token refresh

    func refresh(session: AuthSession) async throws -> AuthSession {
        struct RefreshRequest: Encodable {
            let grantType = "refresh_token"
            let refreshToken: String

            enum CodingKeys: String, CodingKey {
                case grantType = "grant_type"
                case refreshToken = "refresh_token"
            }
        }

        struct RefreshResponse: Decodable {
            let idToken: String
            let refreshToken: String
            let expiresIn: String
            let userId: String

            enum CodingKeys: String, CodingKey {
                case idToken = "id_token"
                case refreshToken = "refresh_token"
                case expiresIn = "expires_in"
                case userId = "user_id"
            }
        }

        let response: RefreshResponse = try await post(
            to: FirebaseConfig.refreshTokenURL,
            body: RefreshRequest(refreshToken: session.refreshToken)
        )

        return AuthSession(
            localID: response.userId,
            email: session.email,
            displayName: session.displayName,
            idToken: response.idToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn) ?? 3600)
        )
    }

    // MARK: Plumbing

    /// Firebase error payload: `{"error": {"code": 400, "message": "INVALID_PASSWORD"}}`.
    private struct FirebaseErrorResponse: Decodable {
        struct Detail: Decodable { let message: String }
        let error: Detail
    }

    private func post<Request: Encodable, Response: Decodable>(
        to url: URL,
        body: Request
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await urlSession.data(for: request)
        } catch {
            throw AuthError.network
        }

        let statusCode = (urlResponse as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(statusCode) else {
            let code = (try? JSONDecoder().decode(FirebaseErrorResponse.self, from: data))?
                .error.message ?? "HTTP \(statusCode)"
            throw Self.mapError(code)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    /// Maps Firebase error codes to user-facing errors.
    private static func mapError(_ code: String) -> AuthError {
        switch code {
        case "EMAIL_NOT_FOUND", "INVALID_PASSWORD", "INVALID_LOGIN_CREDENTIALS", "INVALID_EMAIL":
            return .invalidCredentials
        case "USER_DISABLED":
            return .userDisabled
        case "EMAIL_EXISTS":
            return .emailInUse
        default:
            if code.hasPrefix("TOO_MANY_ATTEMPTS") { return .tooManyAttempts }
            if code.hasPrefix("WEAK_PASSWORD") { return .weakPassword }
            return .server(code)
        }
    }
}
