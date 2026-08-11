//
//  CCComponents.swift
//  ContinenteCargo
//
//  Small, reusable presentation components shared across screens.
//

import SwiftUI

// MARK: - Status badge

/// Pill showing a shipment status with its brand color.
struct StatusBadge: View {
    let status: ShipmentStatus

    var body: some View {
        Label {
            Text(status.badgeTitle)
        } icon: {
            Image(systemName: status.icon)
        }
        .font(.caption.weight(.semibold))
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(status.color)
        .padding(.horizontal, CCSpacing.md)
        .padding(.vertical, CCSpacing.xs + 2)
        .background(status.color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Severity badge

/// Pill showing an alert severity.
struct SeverityBadge: View {
    let severity: AlertSeverity

    var body: some View {
        Text(severity.title.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(severity.color)
            // A badge must never wrap or compress.
            .fixedSize()
            .padding(.horizontal, CCSpacing.sm)
            .padding(.vertical, 3)
            .background(severity.color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Primary button

/// Full-width bright-blue action button with an optional loading state.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    /// Optional icon pinned to the trailing edge (e.g. an arrow).
    var trailingSystemImage: String? = nil
    var isLoading: Bool = false
    var isEnabled: Bool = true
    /// Corner radius; pass `CCRadius.pill` for a fully rounded button.
    var cornerRadius: CGFloat = CCRadius.md
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                HStack(spacing: CCSpacing.sm) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else if let systemImage {
                        Image(systemName: systemImage)
                    }
                    Text(title)
                        .fontWeight(.semibold)
                }
                if let trailingSystemImage, !isLoading {
                    Image(systemName: trailingSystemImage)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, CCSpacing.xl)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(CCColor.actionBlue.opacity(isEnabled && !isLoading ? 1 : 0.5))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Text field

/// Styled text field with a leading icon, used on the login screen.
struct CCTextField: View {
    let title: String
    let systemImage: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboard: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil

    @State private var revealed = false

    var body: some View {
        HStack(spacing: CCSpacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(CCColor.textTertiary)
                .frame(width: 22)

            Group {
                if isSecure && !revealed {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(keyboard)
            .textContentType(textContentType)
            .foregroundStyle(CCColor.textPrimary)

            if isSecure {
                Button {
                    revealed.toggle()
                } label: {
                    Image(systemName: revealed ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(CCColor.textTertiary)
                }
            }
        }
        .padding(.horizontal, CCSpacing.lg)
        .frame(height: 54)
        .background(CCColor.background)
        .clipShape(RoundedRectangle(cornerRadius: CCRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CCRadius.md, style: .continuous)
                .strokeBorder(CCColor.border, lineWidth: 1)
        )
    }
}

// MARK: - Section header

/// Reusable header with a title and optional "Ver todo" trailing action.
struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(CCColor.textPrimary)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CCColor.actionBlue)
            }
        }
    }
}

// MARK: - Filter tab

/// Underlined filter tab with a counter. Shared by the list screens
/// (Embarques, Alertas) so filtering looks identical across the app.
struct FilterTab: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: CCSpacing.sm) {
                HStack(spacing: 5) {
                    Text(title)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? CCColor.navy : CCColor.textSecondary)
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? CCColor.actionBlue : CCColor.textTertiary)
                }
                // Active-tab underline
                Capsule()
                    .fill(isSelected ? CCColor.actionBlue : .clear)
                    .frame(height: 3)
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Labeled detail row

/// A compact label/value pair used in the shipment detail info grid.
struct InfoRow: View {
    let label: String
    let value: String
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(CCColor.textTertiary)
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(CCColor.textSecondary)
                }
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CCColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
