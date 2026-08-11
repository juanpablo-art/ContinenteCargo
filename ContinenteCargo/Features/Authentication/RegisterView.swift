//
//  RegisterView.swift
//  ContinenteCargo
//
//  Account creation sheet, presented from the login screen.
//  Mirrors the login's flat corporate style: labeled fields,
//  pill action button and security footer.
//

import SwiftUI

struct RegisterView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = RegisterViewModel(authService: FirebaseAuthService.shared)

    var body: some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(spacing: CCSpacing.lg) {
                header
                    .padding(.bottom, CCSpacing.sm)

                labeledField(label: "Nombre completo") {
                    CCTextField(title: "Tu nombre y apellido",
                                systemImage: "person",
                                text: $vm.name,
                                textContentType: .name)
                }

                labeledField(label: "Correo electrónico") {
                    CCTextField(title: "ejemplo@correo.com",
                                systemImage: "envelope",
                                text: $vm.email,
                                keyboard: .emailAddress,
                                textContentType: .username)
                }

                labeledField(label: "Contraseña") {
                    CCTextField(title: "Mínimo 6 caracteres",
                                systemImage: "lock",
                                text: $vm.password,
                                isSecure: true,
                                textContentType: .newPassword)
                }

                labeledField(label: "Confirmar contraseña") {
                    CCTextField(title: "Repite tu contraseña",
                                systemImage: "lock",
                                text: $vm.confirmPassword,
                                isSecure: true,
                                textContentType: .newPassword)
                }

                if let message = viewModel.errorMessage {
                    errorBanner(message)
                }

                PrimaryButton(title: "Crear cuenta",
                              trailingSystemImage: "arrow.right",
                              isLoading: viewModel.isLoading,
                              isEnabled: viewModel.canSubmit,
                              cornerRadius: CCRadius.pill) {
                    signUp()
                }

                signInRow

                securityFooter
                    .padding(.top, CCSpacing.sm)
            }
            .padding(.horizontal, CCSpacing.xl)
            .padding(.top, CCSpacing.xxl)
            .padding(.bottom, CCSpacing.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .background(CCColor.background.ignoresSafeArea())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                            to: nil, from: nil, for: nil)
        }
        .overlay(alignment: .topTrailing) {
            closeButton
        }
    }

    // MARK: - Actions

    private func signUp() {
        Task {
            await viewModel.signUp { auth in
                dismiss()
                session.signIn(auth: auth)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: CCSpacing.md) {
            Image("LogoLockupStacked")
                .resizable()
                .scaledToFit()
                .frame(height: 56)
                .accessibilityLabel("Continente Cargo")

            VStack(spacing: CCSpacing.xs) {
                Text("Crear cuenta")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(CCColor.textPrimary)
                Text("Regístrate para dar seguimiento\na tu operación logística.")
                    .font(.subheadline)
                    .foregroundStyle(CCColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.footnote.weight(.bold))
                .foregroundStyle(CCColor.textSecondary)
                .frame(width: 32, height: 32)
                .background(CCColor.surface)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(CCSpacing.lg)
        .accessibilityLabel("Cerrar")
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

    private func errorBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(CCColor.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CCSpacing.md)
            .background(CCColor.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: CCRadius.sm, style: .continuous))
    }

    private var signInRow: some View {
        HStack(spacing: 4) {
            Text("¿Ya tienes cuenta?")
                .font(.footnote)
                .foregroundStyle(CCColor.textSecondary)
            Button("Inicia sesión") { dismiss() }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(CCColor.actionBlue)
        }
        .frame(maxWidth: .infinity)
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
    RegisterView()
        .environment(AppSession())
}
