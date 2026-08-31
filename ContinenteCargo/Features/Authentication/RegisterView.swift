//
//  RegisterView.swift
//  ContinenteCargo
//
//  Formulario de solicitud de acceso. Solo recopila datos del usuario;
//  la empresa activa la cuenta manualmente.
//

import SwiftUI

struct RegisterView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = RegisterViewModel()
    @State private var showSuccessAlert = false

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

                labeledField(label: "Teléfono") {
                    CCTextField(title: "Número de teléfono",
                                systemImage: "phone",
                                text: $vm.phone,
                                keyboard: .phonePad,
                                textContentType: .telephoneNumber)
                }

                if let message = viewModel.errorMessage {
                    errorBanner(message)
                }

                PrimaryButton(title: "Solicitar acceso",
                              trailingSystemImage: "arrow.right",
                              isLoading: viewModel.isLoading,
                              isEnabled: viewModel.canSubmit,
                              cornerRadius: CCRadius.pill) {
                    requestAccess()
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
        .alert("¡Solicitud enviada!", isPresented: $showSuccessAlert) {
            Button("Aceptar") { dismiss() }
        } message: {
            Text("Gracias por registrarte. En seguida un ejecutivo se pondrá en contacto contigo.")
        }
    }

    // MARK: - Actions

    private func requestAccess() {
        Task {
            await viewModel.requestAccess {
                showSuccessAlert = true
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
