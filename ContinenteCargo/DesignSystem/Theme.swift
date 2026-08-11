//
//  Theme.swift
//  ContinenteCargo
//
//  Central design system: colors, spacing, radius and typography.
//  Keeping every visual token in one place keeps the UI consistent
//  and makes a future rebrand a one-file change.
//

import SwiftUI

/// Brand color palette for Continente Cargo.
enum CCColor {
    /// Primary corporate navy. Used for headers, primary text and key surfaces.
    static let navy = Color(hex: 0x0A2540)
    /// Slightly lighter navy for gradients / secondary navy surfaces.
    static let navySoft = Color(hex: 0x123A5E)
    /// Bright, action blue. Buttons, links and interactive accents only.
    static let actionBlue = Color(hex: 0x1B6FF3)
    /// Success / correct states only.
    static let green = Color(hex: 0x1FA971)
    /// Warnings only.
    static let orange = Color(hex: 0xF5A623)
    /// Critical problems only.
    static let red = Color(hex: 0xE5484D)

    /// App background — clean white.
    static let background = Color.white
    /// Card / grouped surface background.
    static let surface = Color(hex: 0xF6F8FB)
    /// Hairline separators and borders.
    static let border = Color(hex: 0xE6EAF0)

    /// Primary text (navy-tinted near-black).
    static let textPrimary = Color(hex: 0x0A2540)
    /// Secondary / supporting text.
    static let textSecondary = Color(hex: 0x6B7A90)
    /// Tertiary / captions.
    static let textTertiary = Color(hex: 0x9AA6B8)
}

/// Consistent spacing scale (4-pt based).
enum CCSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
    static let xxxl: CGFloat = 40
}

/// Corner radius scale.
enum CCRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 20
    static let pill: CGFloat = 100
}

extension Color {
    /// Convenience initializer from a 0xRRGGBB integer literal.
    init(hex: UInt, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension View {
    /// Standard premium card container: white surface, soft border, subtle shadow.
    func ccCard(padding: CGFloat = CCSpacing.lg) -> some View {
        self
            .padding(padding)
            .background(CCColor.background)
            .clipShape(RoundedRectangle(cornerRadius: CCRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CCRadius.lg, style: .continuous)
                    .strokeBorder(CCColor.border, lineWidth: 1)
            )
            .shadow(color: CCColor.navy.opacity(0.05), radius: 12, x: 0, y: 4)
    }
}
