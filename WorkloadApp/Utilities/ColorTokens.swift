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

    static func light(_ rgb: UInt) -> UIColor {
        UIColor(rgb: rgb)
    }
}

/// Semantic color tokens matching the DESIGN.md palette.
/// Tuwa is intentionally light-only; the app forces light appearance.
enum ColorTokens {
    // MARK: - Material roles (UI rebuild v3)
    static let canvas         = background
    static let recessed       = surface
    static let plate          = surfaceEl
    static let control        = surface
    static let raised         = surfaceEl2
    static let active         = surfaceEl2
    static let hairline       = divider
    static let hairlineStrong = dividerStrong
    static let textPrimary    = text1
    static let textSecondary  = text2
    static let textTertiary   = text3
    static let statusPositive = zoneOptimal
    static let statusAttention = zoneCaution
    static let statusCritical = zoneDanger
    static let statusNeutral  = zoneLow

    // MARK: - Backgrounds (Tuwa v2 light-only material ladder)
    static let background    = Color(uiColor: .light(0xECEEF1))
    static let surface       = Color(uiColor: .light(0xF0F2F5))
    static let surfaceEl     = Color(uiColor: .light(0xF8FAFC))
    /// Brightest emphasis plane for the hero/current active surface.
    static let surfaceEl2    = Color(uiColor: .light(0xFCFDFE))
    static let divider       = Color(uiColor: .light(0xC0C5CB))
    /// Stronger hairline for high-priority boundaries.
    static let dividerStrong = Color(uiColor: .light(0xA4ABB2))

    // MARK: - Text
    static let text1        = Color(uiColor: .light(0x14171A))
    static let text2        = Color(uiColor: .light(0x565D63))
    static let text3        = Color(uiColor: .light(0x767D84))

    // MARK: - Accent ("live / actionable / you-are-here")
    static let accent       = Color(uiColor: .light(0x2E6B86))
    /// Low-strength accent wash for selected, active, and progress surfaces.
    static let accentSubtle = accent.opacity(0.16)

    // MARK: - Zone colors (DESIGN.md muted palette — label-led, supplementary only)
    static let zoneOptimal  = Color(uiColor: .light(0x35513F))
    static let zoneCaution  = Color(uiColor: .light(0x57532A))
    static let zoneDanger   = Color(uiColor: .light(0x6B3A3A))
    static let zoneLow      = Color(uiColor: .light(0x384A5C))

    // MARK: - Charts (muted palette variants)
    static let chartATL     = zoneCaution
    static let chartCTL     = zoneLow
    static let chartTSB     = zoneOptimal
    static let chartVolume  = text2
    static let chartHRV     = zoneOptimal
    static let chartSleep   = zoneLow

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
