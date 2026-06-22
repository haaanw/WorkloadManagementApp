import SwiftUI
import UIKit

private extension UIColor {
    convenience init(rgb: UInt) {
        self.init(
            red:   CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >>  8) & 0xFF) / 255,
            blue:  CGFloat( rgb        & 0xFF) / 255,
            alpha: 1
        )
    }

    static func adaptive(dark: UInt, light: UInt) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        }
    }
}

/// Semantic color tokens matching the DESIGN.md palette.
/// All colors support both dark mode (primary) and light mode.
enum ColorTokens {
    // MARK: - Backgrounds (4-plane elevation ladder — Tuwa v2, 2026-06-17)
    // Dark planes widened to a PERCEPTIBLE gap (old ladder sat at ΔL*~3.9, below JND — cards
    // were invisible). Light planes inverted to page-darker / card-lighter so cards lift off the
    // page. Every chrome token is cool true-neutral: blue channel ≥ red channel.
    static let background    = Color(uiColor: .adaptive(dark: 0x090B0D, light: 0xECEEF1))
    static let surface       = Color(uiColor: .adaptive(dark: 0x15191D, light: 0xF0F2F5))
    static let surfaceEl     = Color(uiColor: .adaptive(dark: 0x1F262C, light: 0xF8FAFC))
    /// Emphasis plane — the most important / active surface (hero, selected). The 4th step.
    static let surfaceEl2    = Color(uiColor: .adaptive(dark: 0x28323A, light: 0xFCFDFE))
    static let divider       = Color(uiColor: .adaptive(dark: 0x3D464D, light: 0xC0C5CB))
    /// Stronger hairline for emphasis cards and high-priority cuts (≥2.5:1 over its fill).
    static let dividerStrong = Color(uiColor: .adaptive(dark: 0x525E66, light: 0xA4ABB2))

    // MARK: - Text
    static let text1        = Color(uiColor: .adaptive(dark: 0xECEEF0, light: 0x14171A))
    static let text2        = Color(uiColor: .adaptive(dark: 0xA2AAB0, light: 0x565D63))
    static let text3        = Color(uiColor: .adaptive(dark: 0x747C82, light: 0x767D84))

    // MARK: - Accent (cool stone-blue — the "live / actionable / you-are-here" semantic)
    // Tuwa v2 relaxes the single-accent rule: the accent now marks LIVE state in a defined,
    // restrained set — hero readiness number, strike-zone/progress fills, the active/selected
    // state (set cell, segmented segment, current tab), primary-CTA outline, and the hero card's
    // 2pt top rule. Still ONE hue, used with intent — never on body icons or decoration.
    static let accent       = Color(uiColor: .adaptive(dark: 0x7FB3CC, light: 0x2E6B86))
    /// Translucent accent for active-cell / progress fills behind content.
    static let accentSubtle = accent.opacity(0.16)

    // MARK: - Zone colors (DESIGN.md muted palette — label-led, supplementary only)
    static let zoneOptimal  = Color(uiColor: .adaptive(dark: 0x6E8A78, light: 0x35513F))
    static let zoneCaution  = Color(uiColor: .adaptive(dark: 0x86825E, light: 0x57532A))
    static let zoneDanger   = Color(uiColor: .adaptive(dark: 0x9A6F6F, light: 0x6B3A3A))
    static let zoneLow      = Color(uiColor: .adaptive(dark: 0x6C7886, light: 0x384A5C))

    // MARK: - Charts (cool-only series — warm ATL alias retired 2026-06-17)
    static let chartATL     = Color(uiColor: .adaptive(dark: 0x6A8392, light: 0x2E6B86))
    static let chartCTL     = Color(uiColor: .adaptive(dark: 0x6C7886, light: 0x384A5C))
    static let chartTSB     = Color(uiColor: .adaptive(dark: 0x6E8A78, light: 0x35513F))
    static let chartVolume  = Color(uiColor: .adaptive(dark: 0xA2AAB0, light: 0x565D63))
    static let chartHRV     = Color(uiColor: .adaptive(dark: 0x6E8A78, light: 0x35513F))
    static let chartSleep   = Color(uiColor: .adaptive(dark: 0x6C7886, light: 0x384A5C))

    // MARK: - Legacy aliases (migrate views to new tokens progressively)
    static let primaryAccent       = text1
    static let secondaryAccent     = text2
    static let cardBackground      = surfaceEl
    static let secondaryBackground = background
    static let recoveryRed         = zoneDanger
    static let recoveryYellow      = zoneCaution
    static let recoveryGreen       = zoneOptimal
    static let zoneUndertrained    = zoneLow
    static let zoneNoData          = text3

    // MARK: - Helpers
    static func acwrZoneColor(_ zone: ACWRZone) -> Color {
        switch zone {
        case .undertrained: zoneLow
        case .optimal:      zoneOptimal
        case .caution:      zoneCaution
        case .danger:       zoneDanger
        case .noData:       text3
        }
    }

    static func recoveryZoneColor(_ zone: RecoveryZone) -> Color {
        switch zone {
        case .red:    zoneDanger
        case .yellow: zoneCaution
        case .green:  zoneOptimal
        }
    }
}
