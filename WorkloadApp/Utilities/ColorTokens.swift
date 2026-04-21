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
    // MARK: - Backgrounds
    static let background   = Color(uiColor: .adaptive(dark: 0x0B0B0A, light: 0xF4F1ED))
    static let surface      = Color(uiColor: .adaptive(dark: 0x131312, light: 0xEDEAE6))
    static let surfaceEl    = Color(uiColor: .adaptive(dark: 0x1A1A19, light: 0xE4E0DB))
    static let divider      = Color(uiColor: .adaptive(dark: 0x232321, light: 0xCFCBC5))

    // MARK: - Text
    static let text1        = Color(uiColor: .adaptive(dark: 0xC2BEB7, light: 0x1C1915))
    static let text2        = Color(uiColor: .adaptive(dark: 0x7C7972, light: 0x696560))
    static let text3        = Color(uiColor: .adaptive(dark: 0x3A3835, light: 0xAFABA5))

    // MARK: - Accent (readiness score number only — nowhere else)
    static let accent       = Color(uiColor: .adaptive(dark: 0xA8A090, light: 0x7A6E5C))

    // MARK: - Zone colors (desaturated — state communicated through text, color is supplementary)
    static let zoneOptimal  = Color(uiColor: .adaptive(dark: 0x607869, light: 0x3E5C49))
    static let zoneCaution  = Color(uiColor: .adaptive(dark: 0x7E7252, light: 0x6B5828))
    static let zoneDanger   = Color(uiColor: .adaptive(dark: 0x7E5C5C, light: 0x6E3A3A))
    static let zoneLow      = Color(uiColor: .adaptive(dark: 0x5A6470, light: 0x3A4A5C))

    // MARK: - Charts (muted palette variants of zone colors)
    static let chartATL     = Color(uiColor: .adaptive(dark: 0x7E7252, light: 0x6B5828))
    static let chartCTL     = Color(uiColor: .adaptive(dark: 0x5A6470, light: 0x3A4A5C))
    static let chartTSB     = Color(uiColor: .adaptive(dark: 0x607869, light: 0x3E5C49))
    static let chartVolume  = Color(uiColor: .adaptive(dark: 0x7C7972, light: 0x696560))
    static let chartHRV     = Color(uiColor: .adaptive(dark: 0x607869, light: 0x3E5C49))
    static let chartSleep   = Color(uiColor: .adaptive(dark: 0x5A6470, light: 0x3A4A5C))

    // MARK: - Legacy aliases (migrate views to new tokens progressively)
    static let primaryAccent       = text1
    static let secondaryAccent     = text2
    static let cardBackground      = surface
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
