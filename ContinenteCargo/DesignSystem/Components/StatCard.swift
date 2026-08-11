//
//  StatCard.swift
//  ContinenteCargo
//

import SwiftUI

/// Compact metric tile for the Home executive summary row (4 across).
struct CompactStatCard: View {
    let value: Int
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: CCSpacing.sm) {
            HStack(alignment: .top) {
                Text("\(value)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                Spacer(minLength: 0)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(CCColor.textSecondary)
                .lineLimit(2, reservesSpace: true)
                .minimumScaleFactor(0.85)
        }
        .padding(CCSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CCColor.background)
        .clipShape(RoundedRectangle(cornerRadius: CCRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CCRadius.md, style: .continuous)
                .strokeBorder(CCColor.border, lineWidth: 1)
        )
    }
}

/// Wide highlight card for the primary metric (active shipments).
/// Clean white surface with a navy icon tile.
struct HeroStatCard: View {
    let value: Int
    let title: String

    var body: some View {
        HStack(alignment: .center, spacing: CCSpacing.lg) {
            VStack(alignment: .leading, spacing: CCSpacing.xs) {
                Text("\(value)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(CCColor.textPrimary)
                    .contentTransition(.numericText())

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CCColor.textSecondary)
            }

            Spacer()

            // Navy brand tile with a vessel icon.
            ZStack {
                RoundedRectangle(cornerRadius: CCRadius.md, style: .continuous)
                    .fill(
                        LinearGradient(colors: [CCColor.navy, CCColor.navySoft],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                Image(systemName: "ferry.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)
        }
        .ccCard(padding: CCSpacing.xl)
    }
}
