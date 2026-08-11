//
//  ShippingAlertRow.swift
//  ContinenteCargo
//
//  Row summarizing one alerted shipping from the Continente API,
//  with its reasons. Used in Alerts and Home.
//

import SwiftUI

struct ShippingAlertRow: View {
    let alert: ShippingAlert
    /// When true a chevron is shown to hint at navigation.
    var showsChevron: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: CCSpacing.md) {
            // Severity-tinted icon tile
            ZStack {
                RoundedRectangle(cornerRadius: CCRadius.sm, style: .continuous)
                    .fill(alert.severity.color.opacity(0.12))
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(alert.severity.color)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(alert.refCode ?? "Embarque \(alert.shippingId)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CCColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: CCSpacing.sm)
                    SeverityBadge(severity: alert.severity)
                }

                // Every reason reported for this shipping.
                ForEach(Array((alert.reasons ?? []).enumerated()), id: \.offset) { _, reason in
                    if let description = reason.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(CCColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Delay chips
                if hasDelays {
                    HStack(spacing: CCSpacing.sm) {
                        if let etd = alert.etdDelayDays, etd > 0 {
                            delayChip("ETD +\(etd) d")
                        }
                        if let eta = alert.etaDelayDays, eta > 0 {
                            delayChip("ETA +\(eta) d")
                        }
                    }
                }

                // Context: route, containers, last update.
                // Time label keeps fixedSize; route truncates if the string is long.
                HStack(spacing: CCSpacing.md) {
                    if let route = alert.route {
                        Label(route, systemImage: "arrow.left.arrow.right")
                            .lineLimit(1)
                            .layoutPriority(-1)
                    }
                    if let containers = alert.containerNumbers, !containers.isEmpty {
                        Label(containers, systemImage: "shippingbox.fill")
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if let updatedAt = alert.updatedAt {
                        Label(CCFormat.relativeSince(updatedAt), systemImage: "clock")
                            .fixedSize()
                    }
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

    private var hasDelays: Bool {
        (alert.etdDelayDays ?? 0) > 0 || (alert.etaDelayDays ?? 0) > 0
    }

    private func delayChip(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(alert.severity.color)
            .padding(.horizontal, CCSpacing.sm)
            .padding(.vertical, 3)
            .background(alert.severity.color.opacity(0.1))
            .clipShape(Capsule())
    }
}
