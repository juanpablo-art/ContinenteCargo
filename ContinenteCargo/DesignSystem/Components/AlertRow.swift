//
//  AlertRow.swift
//  ContinenteCargo
//

import SwiftUI

/// Row summarizing a single logistic alert. Used in Alerts and Home.
struct AlertRow: View {
    let alert: LogisticAlert
    /// When true a chevron is shown to hint at navigation.
    var showsChevron: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: CCSpacing.md) {
            // Severity-tinted icon tile
            ZStack {
                RoundedRectangle(cornerRadius: CCRadius.sm, style: .continuous)
                    .fill(alert.severity.color.opacity(0.12))
                Image(systemName: alert.type.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(alert.severity.color)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(alert.type.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CCColor.textPrimary)
                        .lineLimit(1)
                        // Shrink slightly instead of wrapping when space is tight.
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: CCSpacing.sm)
                    SeverityBadge(severity: alert.severity)
                }

                Text(alert.message)
                    .font(.caption)
                    .foregroundStyle(CCColor.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: CCSpacing.md) {
                    Label(alert.shipmentReference, systemImage: "shippingbox.fill")
                    Label(CCFormat.relativeSince(alert.detectedAt), systemImage: "clock")
                }
                .font(.caption2)
                .foregroundStyle(CCColor.textTertiary)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CCColor.textTertiary)
                    .padding(.top, CCSpacing.md)
            }
        }
        .ccCard(padding: CCSpacing.md)
    }
}
