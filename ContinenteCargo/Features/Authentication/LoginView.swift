//
//  LoginView.swift
//  ContinenteCargo
//
//  Flat, corporate login matching the brand mockup:
//  logo + maritime header, labeled fields, remember-me row,
//  pill action button and security footer.
//

import SwiftUI

struct LoginView: View {
    @Environment(AppSession.self) private var session
    @State private var viewModel = LoginViewModel(authService: FirebaseAuthService.shared)
    @State private var rememberMe = false
    @State private var showForgotAlert = false
    @State private var showRegister = false

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(spacing: 0) {
                brandHeader

                VStack(spacing: CCSpacing.lg) {
                    welcomeBlock
                        .padding(.bottom, CCSpacing.sm)

                    labeledField(label: "Correo electrónico") {
                        CCTextField(title: "ejemplo@correo.com",
                                    systemImage: "envelope",
                                    text: $vm.email,
                                    keyboard: .emailAddress,
                                    textContentType: .username)
                    }

                    labeledField(label: "Contraseña") {
                        CCTextField(title: "Ingresa tu contraseña",
                                    systemImage: "lock",
                                    text: $vm.password,
                                    isSecure: true,
                                    textContentType: .password)
                    }

                    rememberRow

                    if let message = viewModel.errorMessage {
                        errorBanner(message)
                    }

                    PrimaryButton(title: "Iniciar sesión",
                                  trailingSystemImage: "arrow.right",
                                  isLoading: viewModel.isLoading,
                                  isEnabled: viewModel.canSubmit,
                                  cornerRadius: CCRadius.pill) {
                        signIn()
                    }

                    registerRow

                    securityFooter
                        .padding(.top, CCSpacing.sm)
                }
                .padding(.horizontal, CCSpacing.xl)
                .padding(.top, CCSpacing.xl)
                .padding(.bottom, CCSpacing.xxl)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .background(CCColor.background.ignoresSafeArea())
        // Tap anywhere outside the fields to dismiss the keyboard.
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
        }
        .alert("Recuperar contraseña", isPresented: $showForgotAlert) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("Se enviará un enlace de recuperación al correo registrado.")
        }
    }

    // MARK: - Actions

    private func signIn() {
        Task {
            await viewModel.signIn { auth in
                session.signIn(auth: auth)
            }
        }
    }

    // MARK: - Header

    private var brandHeader: some View {
        VStack(spacing: 0) {
            logo
                .padding(.top, CCSpacing.xl)
                .padding(.bottom, CCSpacing.lg)

            // Faded maritime strip under the logo, washed out to white.
            maritimeStrip
        }
    }

    private var logo: some View {
        // Official brand lockup (stacked wordmark + isotype).
        Image("LogoLockupStacked")
            .resizable()
            .scaledToFit()
            .frame(height: 76)
            .accessibilityLabel("Continente Cargo")
    }

    /// Decorative, washed-out maritime scene rendered with SF Symbols.
    private var maritimeStrip: some View {
        ZStack {
            HStack(spacing: CCSpacing.xxl) {
                Image(systemName: "ferry.fill")
                    .font(.system(size: 54))
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 30))
                    .offset(y: 12)
                Image(systemName: "airplane")
                    .font(.system(size: 38))
                    .offset(y: -18)
                Image(systemName: "ferry.fill")
                    .font(.system(size: 44))
                    .offset(y: 6)
            }
            .foregroundStyle(CCColor.navy.opacity(0.10))

            // White wash so the scene fades into the content below.
            LinearGradient(colors: [.white.opacity(0), .white],
                           startPoint: .top, endPoint: .bottom)
        }
        .frame(height: 90)
        .clipped()
    }

    // MARK: - Welcome

    private var welcomeBlock: some View {
        VStack(spacing: CCSpacing.xs) {
            Text("Bienvenido")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(CCColor.textPrimary)
            Text("Accede a tu operación logística\nen tiempo real.")
                .font(.subheadline)
                .foregroundStyle(CCColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Form helpers

    private func labeledField(label: String, @ViewBuilder field: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: CCSpacing.sm) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(CCColor.textPrimary)
            field()
        }
    }

    private var rememberRow: some View {
        HStack {
            Button {
                rememberMe.toggle()
            } label: {
                HStack(spacing: CCSpacing.sm) {
                    Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                        .font(.system(size: 18))
                        .foregroundStyle(rememberMe ? CCColor.actionBlue : CCColor.textTertiary)
                    Text("Recuérdame")
                        .font(.footnote)
                        .foregroundStyle(CCColor.textSecondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button("¿Olvidaste tu contraseña?") { showForgotAlert = true }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(CCColor.actionBlue)
        }
    }

    private var registerRow: some View {
        HStack(spacing: 4) {
            Text("¿No tienes cuenta?")
                .font(.footnote)
                .foregroundStyle(CCColor.textSecondary)
            Button("Regístrate") { showRegister = true }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(CCColor.actionBlue)
        }
        .frame(maxWidth: .infinity)
    }

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(CCColor.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CCSpacing.md)
            .background(CCColor.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: CCRadius.sm, style: .continuous))
    }

    // MARK: - Footer

    private var securityFooter: some View {
        HStack(spacing: CCSpacing.md) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 16))
                .foregroundStyle(CCColor.actionBlue)
            Text("Tus datos están protegidos con los más altos estándares de seguridad.")
                .font(.caption2)
                .foregroundStyle(CCColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, CCSpacing.lg)
        .padding(.vertical, CCSpacing.md)
        .background(CCColor.surface)
        .clipShape(Capsule())
    }
}

#Preview {
    LoginView()
        .environment(AppSession())
}
