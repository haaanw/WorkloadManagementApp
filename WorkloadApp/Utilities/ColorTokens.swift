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

    // MARK: - Relief (DESIGN.md v4.2 "Machined" — Relief Law; used ONLY by .raised/.debossed)
    /// 1px milled top-highlight inside RAISED plates (white @ 0.85).
    static let reliefHighlight     = Color.white.opacity(0.85)
    /// Softer bottom inner highlight closing a DEBOSSED pocket (white @ 0.55).
    static let reliefHighlightSoft = Color.white.opacity(0.55)
    /// Inner top shade of a DEBOSSED pocket (ink @ 0.08) — the cut edge.
    static let reliefShade         = Color(uiColor: .light(0x17181A)).opacity(0.08)
    /// `#E0E1E4 → #E7E8EA` — the debossed well's vertical gradient (top → bottom).
    static let wellTop             = Color(uiColor: .light(0xE0E1E4))
    static let wellBottom          = Color(uiColor: .light(0xE7E8EA))

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
    /// `#232527` — TOP endpoint of the panel component's vertical gradient. Reserved for
    /// `panelStyle()` (CardStyle.swift) — everywhere else uses the flat `panel` token.
    static let panelGradientTop = Color(uiColor: .light(0x232527))
    /// `#1A1C1E` — BOTTOM endpoint of the panel component's vertical gradient. Reserved for
    /// `panelStyle()` (CardStyle.swift) — everywhere else uses the flat `panel` token.
    static let panelGradientBottom = Color(uiColor: .light(0x1A1C1E))

    // MARK: - Chrome (v4 instrument chrome surfaces)
    /// `#E7E8EA` — the tab-bar plane: a hair darker than `background` so the bar reads as
    /// the machined bottom edge of the instrument body (mockup D tab bar).
    static let tabBarSurface = Color(uiColor: .light(0xE7E8EA))

    // MARK: - Tick scale (TickScale component colors — column D mockup vars)
    /// `#4E5154` — minor tick marks (1px weight) on the TickScale.
    static let tickMinor    = Color(uiColor: .light(0x4E5154))
    /// `#6E7175` — major tick marks (1.5px weight) on the TickScale.
    static let tickMajor    = Color(uiColor: .light(0x6E7175))
    /// `#8B8F94` — tick numerals (equals `panelInk2` by design — the dial numeral gray).
    static let tickNumeral  = Color(uiColor: .light(0x8B8F94))

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

    // MARK: - Charts (v4.1 instrument traces — WS3 retune 2026-07-20)
    // The v4.0 chart series aliased the olive/moss zone tokens, which read as alarm colors on
    // the aluminum body. Retuned to instrument traces: cool-neutral inks graded by lightness
    // for the load/volume series, plus ONE muted supporting hue (a desaturated instrument teal,
    // `#4E7A74`) reserved for the "positive" series (form/TSB + HRV) so a single-series
    // physiology chart still carries a hint of life. Semantic pairing preserved (acute =
    // prominent dark, chronic base = quiet light, form = the hue). Inter-series
    // distinguishability ≥3:1 on the co-plotted load chart (ATL dark vs CTL light vs TSB teal,
    // separated by lightness + hue). Dedicated hex literals — do not re-alias zone tokens.
    /// `#33383D` — dark cool ink. Acute load (ATL): the prominent, volatile line.
    static let chartATL     = Color(uiColor: .light(0x33383D))
    /// `#8B9096` — light cool ink. Chronic base (CTL): the quiet backbone line.
    static let chartCTL     = Color(uiColor: .light(0x8B9096))
    /// `#4E7A74` — the ONE muted supporting hue (desaturated instrument teal). Training-stress
    /// balance / form: the positive series.
    static let chartTSB     = Color(uiColor: .light(0x4E7A74))
    /// `#6E757B` — mid cool ink. Session-volume bars.
    static let chartVolume  = Color(uiColor: .light(0x6E757B))
    /// `#4E7A74` — supporting teal (shares TSB's positive hue). HRV: positive physiology.
    static let chartHRV     = Color(uiColor: .light(0x4E7A74))
    /// `#5A6066` — mid-dark cool ink. Sleep duration.
    static let chartSleep   = Color(uiColor: .light(0x5A6066))

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
