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

/// Semantic color tokens matching the DESIGN.md v4 "Instrument" (Aluminum Panel) palette.
/// Tuwa is intentionally light-only; the app forces light appearance.
///
/// v4 material model (2026-07-20): an aluminum body (`background` base, `surfaceEl` cards,
/// cool-neutral hairlines) carrying at most ONE near-black instrument panel per screen
/// (`panel` + `panelInk`/`panelInk2`/`panelHairline`), with a single red index accent
/// (`index`) reserved for index MARKS — scale needles, the active-tab tick, a live-recording
/// dot. Never a fill, never text, never decorative.
enum ColorTokens {
    // MARK: - Material roles (UI rebuild v3 — names retained, values retuned v4)
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

    // MARK: - Backgrounds (v4 aluminum body — flat base token; a subtle vertical gradient
    // is sanctioned ONLY on the scroll background, built in Stage 1″, never per-card)
    /// `#E9EAEB` — the aluminum base plane (page/scroll canvas).
    static let background    = Color(uiColor: .light(0xE9EAEB))
    /// `#EFF0F1` — inline strip / control plane, between base and card.
    static let surface       = Color(uiColor: .light(0xEFF0F1))
    /// `#F5F6F7` — the card plane (v4 canonical card fill).
    static let surfaceEl     = Color(uiColor: .light(0xF5F6F7))
    /// `#FAFBFB` — brightest light plane (active/selected surfaces). The v4 EMPHASIS surface
    /// for the hero reading is the black `panel`, not a brighter light plane.
    static let surfaceEl2    = Color(uiColor: .light(0xFAFBFB))
    /// `#D0D2D5` — hairline rules on aluminum.
    static let divider       = Color(uiColor: .light(0xD0D2D5))
    /// `#C6C9CC` — stronger hairline: key-row container borders, high-priority boundaries.
    static let dividerStrong = Color(uiColor: .light(0xC6C9CC))

    // MARK: - Text (aluminum surfaces)
    /// `#17181A` — ink. 14.8:1 on base.
    static let text1        = Color(uiColor: .light(0x17181A))
    /// `#4A4D51` — secondary. 7.1:1 on base.
    static let text2        = Color(uiColor: .light(0x4A4D51))
    /// `#85898E` — tertiary / micro-caps. 2.9:1 on base (≥3:1 on card).
    static let text3        = Color(uiColor: .light(0x85898E))
    /// `#9A9EA3` — disabled-only text/glyphs. Below contrast floors by design; never for
    /// information-carrying copy.
    static let disabled     = Color(uiColor: .light(0x9A9EA3))

    // MARK: - Panel plane (the v4 signature — max ONE per screen, hero instrument reading only)
    /// `#1E2022` — the near-black instrument panel fill (flat token; the mockup's
    /// `#232527 → #1A1C1E` vertical gradient is applied by the Stage 1″ panel component only).
    static let panel         = Color(uiColor: .light(0x1E2022))
    /// `#F0F1F2` — primary ink on the panel. 14.3:1 on `panel`.
    static let panelInk      = Color(uiColor: .light(0xF0F1F2))
    /// `#8B8F94` — secondary ink on the panel (micro-labels, units). 5.0:1 on `panel`.
    static let panelInk2     = Color(uiColor: .light(0x8B8F94))
    /// `#35373A` — hairline rules inside/around the panel.
    static let panelHairline = Color(uiColor: .light(0x35373A))

    // MARK: - Index accent (v4 accent law)
    /// `#D04234` — the red index. INDEX MARKS ONLY: scale needles, the active-tab tick,
    /// a live-recording dot. Never a fill, never text, never decorative. Marks are ≥1.5pt
    /// strokes so the sub-4.5:1 text contrast is irrelevant by construction.
    static let index        = Color(uiColor: .light(0xD04234))

    /// v2/v3 alias — re-pointed to the red index in v4. Existing live-state call sites
    /// (progress fills, focused borders, emphasis rules) keep compiling; Stage 1″/2″
    /// restyles them to the Index Rule (needle/tick grammar) screen by screen.
    static let accent       = index
    /// Low-strength accent wash — retained for compile compatibility; Stage 1″/2″ migrates
    /// active/selected surfaces to ink + hairline grammar instead of accent washes.
    static let accentSubtle = accent.opacity(0.16)

    // MARK: - Zone colors (v4 instrument variants — label-led, supplementary only.
    // All ≥4.5:1 on both light surfaces (base #E9EAEB / card #F5F6F7); verified 2026-07-20.)
    /// `#3F5A46` — desaturated instrument green. 6.3:1 base / 7.0:1 card.
    static let zoneOptimal  = Color(uiColor: .light(0x3F5A46))
    /// `#6E5624` — desaturated instrument amber. 5.8:1 base / 6.4:1 card.
    static let zoneCaution  = Color(uiColor: .light(0x6E5624))
    /// `#7E362E` — desaturated instrument red (distinct from the brighter `index`). 7.1:1 / 7.9:1.
    static let zoneDanger   = Color(uiColor: .light(0x7E362E))
    /// `#46525E` — desaturated slate (undertrained / neutral). 6.6:1 / 7.4:1.
    static let zoneLow      = Color(uiColor: .light(0x46525E))

    // MARK: - Charts (instrument-variant series)
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
