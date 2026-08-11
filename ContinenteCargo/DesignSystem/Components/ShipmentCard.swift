//
//  ShipmentCard.swift
//  ContinenteCargo
//
//  Card summarizing a shipment, used in the Shipments list.
//  Layout per brand mockup: status icon tile, reference + status pill,
//  route, ETA, container and last update, with a trailing chevron.
//

import SwiftUI

struct ShipmentCard: View {
    let shipment: Shipment

    /// Attention cards surface a warning glyph; others show their transport mode.
    private var tileIcon: String {
        shipment.requiresAttention ? "exclamationmark.triangle.fill" : shipment.transportMode.icon
    }

    /// Returns nil when the API returned no ETA (sentinel is Date.distantFuture).
    private var etaText: String? {
        shipment.eta < .distantFuture ? CCFormat.date(shipment.eta) : nil
    }

    /// Returns nil when the API returned no ETD (sentinel is Date.distantPast).
    private var etdText: String? {
        shipment.etd > .distantPast ? CCFormat.date(shipment.etd) : nil
    }

    private var hasRoute: Bool {
        !shipment.originName.isEmpty || !shipment.destinationName.isEmpty
    }

    var body: some View {
        HStack(alignment: .center, spacing: CCSpacing.md) {
            // Status-tinted icon tile
            ZStack {
                RoundedRectangle(cornerRadius: CCRadius.sm, style: .continuous)
                    .fill(shipment.status.color.opacity(0.12))
                Image(systemName: tileIcon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(shipment.status.color)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 5) {
                // Reference + status pill
                HStack(alignment: .center) {
                    Text(shipment.reference)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(CCColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: CCSpacing.sm)
                    StatusBadge(status: shipment.status)
                }

                // Route — hidden when both origin and destination are empty.
                if hasRoute {
                    HStack(spacing: 5) {
                        Text(shipment.originName)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(CCColor.textTertiary)
                        Text(shipment.destinationName)
                    }
                    .font(.footnote)
                    .foregroundStyle(CCColor.textPrimary)
                    .lineLimit(1)
                }

                // ETD / ETA — only shown when the API provides a real date.
                if let etd = etdText, let eta = etaText {
                    Text("ETD: \(etd)  ·  ETA: \(eta)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(shipment.requiresAttention ? CCColor.red : CCColor.actionBlue)
                        .lineLimit(1)
                } else if let eta = etaText {
                    Text("ETA: \(eta)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(shipment.requiresAttention ? CCColor.red : CCColor.actionBlue)
                } else if let etd = etdText {
                    Text("ETD: \(etd)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(CCColor.actionBlue)
                }

                // Container — only shown when available.
                if !shipment.container.isEmpty {
                    Text("Contenedor: \(shipment.container)")
                        .font(.caption)
                        .foregroundStyle(CCColor.textSecondary)
                        .lineLimit(1)
                }

                // Last update
                Text("Última actualización: \(CCFormat.relativeSince(shipment.lastUpdate).lowercased())")
                    .font(.caption2)
                    .foregroundStyle(CCColor.textTertiary)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CCColor.textTertiary)
        }
        .ccCard()
    }
}
