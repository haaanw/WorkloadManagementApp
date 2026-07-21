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

/// Semantic color tokens matching the DESIGN.md v5 "Pavilion" (Warm Stone) palette.
/// Tuwa is intentionally light-only; the app forces light appearance.
///
/// v5 material model (2026-07-21): ONE warm stone material in ascending planes of light
/// (the relief system needs raised = brighter), warm ink, and a single travertine accent
/// (`accent`) reserved for the hero readiness score and live-state marks (progress fills,
/// active/selected marks, the tab tick, recording dot, needles). Never decorative, never
/// a CTA fill, never labels.
///
/// Retired with v4 (tokens deleted): the near-black panel plane and the red index —
/// index marks (needles, the tab tick, the recording dot) are drawn in accent.
enum ColorTokens {
    // MARK: - Material roles (UI rebuild v3 — names retained, values retuned v5)
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

    // MARK: - Backgrounds (v5 warm stone — ascending planes of light)
    /// `#F0EFEC` — the stone base plane (page/scroll canvas).
    static let background    = Color(uiColor: .light(0xF0EFEC))
    /// `#F4F3F0` — inline strip / control plane, between base and card.
    static let surface       = Color(uiColor: .light(0xF4F3F0))
    /// `#F8F7F4` — the card plane (v5 canonical card fill).
    static let surfaceEl     = Color(uiColor: .light(0xF8F7F4))
    /// `#FCFBF9` — brightest plane: raised tops, active/selected surfaces.
    static let surfaceEl2    = Color(uiColor: .light(0xFCFBF9))
    /// `#D6D3CD` — hairline rules on stone.
    static let divider       = Color(uiColor: .light(0xD6D3CD))
    /// `#CCC9C2` — stronger hairline: key-row container borders, high-priority boundaries.
    static let dividerStrong = Color(uiColor: .light(0xCCC9C2))

    // MARK: - Relief (v4.2 Relief Law carried into v5; used ONLY by .raised/.debossed)
    /// 1px milled top-highlight inside RAISED plates (white @ 0.85).
    static let reliefHighlight     = Color.white.opacity(0.85)
    /// Softer bottom inner highlight closing a DEBOSSED pocket (white @ 0.55).
    static let reliefHighlightSoft = Color.white.opacity(0.55)
    /// Inner top shade of a DEBOSSED pocket (warm ink @ 0.08) — the cut edge.
    static let reliefShade         = Color(uiColor: .light(0x1B1A17)).opacity(0.08)
    /// `#E7E5E0 → #EDEBE6` — the debossed well's vertical gradient (top → bottom).
    static let wellTop             = Color(uiColor: .light(0xE7E5E0))
    static let wellBottom          = Color(uiColor: .light(0xEDEBE6))

    // MARK: - Text (warm ink)
    /// `#1B1A17` — warm ink. ≈15:1 on base.
    static let text1        = Color(uiColor: .light(0x1B1A17))
    /// `#57544E` — secondary. ≈6.5:1 on base.
    static let text2        = Color(uiColor: .light(0x57544E))
    /// `#8B877F` — tertiary / micro-caps (≥3:1 on card).
    static let text3        = Color(uiColor: .light(0x8B877F))
    /// `#A19D95` — disabled-only text/glyphs. Below contrast floors by design; never for
    /// information-carrying copy.
    static let disabled     = Color(uiColor: .light(0xA19D95))
    /// `#F6F5F2` — light text on ink fills (the primary-CTA text color).
    static let inkInverse   = Color(uiColor: .light(0xF6F5F2))

    // MARK: - Accent (v5 travertine law)
    /// `#6F6759` — travertine. The hero readiness score (the ONE colored text element in
    /// the app) plus live-state marks: progress fills, active/selected marks, the
    /// active-tab tick, the live-recording dot, scale needles. Never decorative, never a
    /// CTA fill, never labels. ≈4.9:1 on base — clears the 3:1 large-text floor with room.
    static let accent       = Color(uiColor: .light(0x6F6759))
    /// Low-strength accent wash for active/selected surfaces (live-state only).
    static let accentSubtle = accent.opacity(0.14)

    // MARK: - Chrome
    /// `#ECEBE7` — the tab-bar plane: a hair darker than `background` so the bar reads as
    /// the bottom edge of the stone body.
    static let tabBarSurface = Color(uiColor: .light(0xECEBE7))

    // MARK: - Tick scale (TickScale component colors — v5 warm grays)
    /// `#63605A` — minor tick marks (1px weight) on the TickScale.
    static let tickMinor    = Color(uiColor: .light(0x63605A))
    /// `#7C786F` — major tick marks (1.5px weight) on the TickScale.
    static let tickMajor    = Color(uiColor: .light(0x7C786F))
    /// `#8B877F` — tick numerals (equals `text3` by design).
    static let tickNumeral  = Color(uiColor: .light(0x8B877F))

    // MARK: - Zone colors (desaturated, label-led, supplementary only — contrast-verified
    // values retained from v4; all ≥4.5:1 on the stone surfaces.)
    /// `#3F5A46` — desaturated green.
    static let zoneOptimal  = Color(uiColor: .light(0x3F5A46))
    /// `#6E5624` — desaturated amber.
    static let zoneCaution  = Color(uiColor: .light(0x6E5624))
    /// `#7E362E` — desaturated red.
    static let zoneDanger   = Color(uiColor: .light(0x7E362E))
    /// `#46525E` — desaturated slate (undertrained / neutral).
    static let zoneLow      = Color(uiColor: .light(0x46525E))

    // MARK: - Charts (v5 warm-ink traces)
    // Warm inks graded by lightness for the load/volume series, plus ONE muted supporting
    // hue (desaturated teal `#4E7A74`) reserved for the positive series (form/TSB + HRV).
    // Semantic pairing preserved (acute = prominent dark, chronic base = quiet light,
    // form = the hue). Dedicated hex literals — do not re-alias zone tokens.
    /// `#3A3733` — dark warm ink. Acute load (ATL): the prominent, volatile line.
    static let chartATL     = Color(uiColor: .light(0x3A3733))
    /// `#97928A` — light warm ink. Chronic base (CTL): the quiet backbone line.
    static let chartCTL     = Color(uiColor: .light(0x97928A))
    /// `#4E7A74` — the ONE muted supporting hue (desaturated teal). Training-stress
    /// balance / form: the positive series.
    static let chartTSB     = Color(uiColor: .light(0x4E7A74))
    /// `#767168` — mid warm ink. Session-volume bars.
    static let chartVolume  = Color(uiColor: .light(0x767168))
    /// `#4E7A74` — supporting teal (shares TSB's positive hue). HRV: positive physiology.
    static let chartHRV     = Color(uiColor: .light(0x4E7A74))
    /// `#5F5A52` — mid-dark warm ink. Sleep duration.
    static let chartSleep   = Color(uiColor: .light(0x5F5A52))

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
