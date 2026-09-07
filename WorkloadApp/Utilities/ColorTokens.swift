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

/// The functional areas of the app that own a metric hue (DESIGN.md v6.3 "The Area Tint").
///
/// An area's hue is the metric family of its PRIMARY reading, so the hue an athlete is bathed
/// in names where they are standing. A surface with no metric identity — Profile, settings,
/// auth, onboarding — has no `MetricArea` and stays untinted stone; that is the default, not
/// an opt-out (see `EnvironmentValues.metricArea`, which is `nil` unless a screen declares one).
enum MetricArea: String, CaseIterable, Sendable {
    /// Home / Today. The day's readiness reading and the proposal built on it.
    case readiness
    /// Trends' recovery surfaces — HRV and the recovery physiology behind the score.
    case recovery
    /// Sleep detail — the night list, the per-night breakdown, the sleep charts.
    case sleep
    /// Log / capture — the session surfaces where strain is produced and recorded.
    case strain
    /// Load surfaces — ACWR, the load trend, the training-load widget.
    case load
}

/// Semantic color tokens matching the DESIGN.md v6 "Field Notes" palette — an OVERLAY on
/// v5 "Pavilion" (Warm Stone), ported from `design-system/tokens/colors.css`.
/// Tuwa is intentionally light-only; the app forces light appearance.
///
/// Material model (v5, unchanged in v6): ONE warm stone material in ascending planes of light
/// (the relief system needs raised = brighter) plus warm ink.
///
/// **What v6 changed here — three things:**
/// 1. **Five metric hues** (`metricReadiness`/`Recovery`/`Sleep`/`Strain`/`Load`) — each metric
///    owns a hue, so a legend is never needed. Usable as series lines, state dots, chart "now"
///    markers, and hero readings. NEVER as a plane fill, card background, CTA fill, or
///    decorative tint: a hue identifies a *measurement*, it never dresses a *surface*.
///    These five are the ONLY colors v6 adds — the fence test enumerates the set.
/// 2. **Re-tuned zone colors** — more chromatic than v5's near-grays (a gym-floor legibility
///    gain). The Zone Color Rule is untouched: state reads from the TEXT LABEL first, color is
///    supplementary, never color alone. Badges are text + hairline capsule, never a fill.
/// 3. **`chartGrid`** — the hairline chart grid token.
///
/// **The Reading Color Rule (v6, supersedes the v5 Accent Rule):** the hero reading takes its
/// own metric's hue; `accent` (travertine) owns live-state marks EXCLUSIVELY (progress fills,
/// active/selected marks, the tab tick, the recording dot, needles) plus hero readings that have
/// no metric identity. Neither may ever be decorative, a CTA fill, or label text.
///
/// **Contrast (measured, see DESIGN.md "Contrast floors"):** every metric hue and zone color
/// clears 4.5:1 on the CARD planes (`surfaceEl`/`surfaceEl2`), but `metricReadiness`/`zoneOptimal`
/// measures 4.39:1 and `metricLoad` 4.49:1 on the `background` base plane. So: hue/zone-colored
/// TEXT below 24pt belongs on a card plane; hero readings (≥32pt) may sit on any plane (3:1
/// large-text floor); marks (lines, dots, needles) are unrestricted (3:1 graphical floor).
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

    // MARK: - Raw stone + hue values (the ONE source the area-tint math mixes from)
    // The v6.3 area tint is computed, not hand-picked, so the two ingredients it mixes —
    // the five metric hues and the three planes/rules it washes — must exist as NUMBERS
    // somewhere. They live here, once, and the public `Color` tokens below are derived from
    // them. Duplicating a hex to feed the mixer would be exactly the drift the tint's
    // single-formula law exists to prevent.
    fileprivate enum Raw {
        static let hueReadiness: UInt = 0x2E7D4F
        static let hueRecovery:  UInt = 0x1D7189
        static let hueSleep:     UInt = 0x52589E
        static let hueStrain:    UInt = 0xA8442D
        static let hueLoad:      UInt = 0x8A6810
        /// The card plane — what a hero card is washed over.
        static let planeCard:      UInt = 0xF8F7F4
        /// The brightest plane — the top stop of a RAISED hero's gradient.
        static let planeRaisedTop: UInt = 0xFCFBF9
        /// The hairline rule the area tint tints.
        static let rule: UInt = 0xD6D3CD
    }

    // MARK: - Backgrounds (v5 warm stone — ascending planes of light)
    /// `#F0EFEC` — the stone base plane (page/scroll canvas).
    static let background    = Color(uiColor: .light(0xF0EFEC))
    /// `#F4F3F0` — inline strip / control plane, between base and card.
    static let surface       = Color(uiColor: .light(0xF4F3F0))
    /// `#F8F7F4` — the card plane (v5 canonical card fill).
    static let surfaceEl     = Color(uiColor: .light(Raw.planeCard))
    /// `#FCFBF9` — brightest plane: raised tops, active/selected surfaces.
    static let surfaceEl2    = Color(uiColor: .light(Raw.planeRaisedTop))
    /// `#D6D3CD` — hairline rules on stone.
    static let divider       = Color(uiColor: .light(Raw.rule))
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
    /// `#F4F3F0` — light text on ink fills (the primary-CTA text color). v6 aligns this to
    /// `--ink-inverse` in the design system (was `#F6F5F2` in v5).
    static let inkInverse   = Color(uiColor: .light(0xF4F3F0))

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

    // MARK: - Metric identities (v6 "Field Notes" — the five icon-derived hues)
    // Grown from the app icon's five hue families, re-tuned 2026-07-28 for mutual
    // distinguishability (wide hue spread, varied lightness). EACH METRIC OWNS ITS HUE — that
    // is what makes legends unnecessary. Permitted: series lines, state dots, chart "now"
    // markers, hero readings (by identity). BANNED: plane fills, card backgrounds, CTA fills,
    // decorative tints, icon tints at rest. Adding a sixth hue is a design change, not a
    // token addition — `DesignSystemFenceTests` enumerates this set.
    /// `#2E7D4F` — verdant green. Readiness / recovery score. (Deliberately the same value as
    /// `zoneOptimal`: a zone IS a readiness statement. Not an accident to "fix".)
    static let metricReadiness = Color(uiColor: .light(Raw.hueReadiness))
    /// `#1D7189` — teal. HRV / recovery physiology.
    static let metricRecovery  = Color(uiColor: .light(Raw.hueRecovery))
    /// `#52589E` — indigo. Sleep. (Deliberately the same value as `zoneLow`.)
    static let metricSleep     = Color(uiColor: .light(Raw.hueSleep))
    /// `#A8442D` — rust. Strain / acute load.
    static let metricStrain    = Color(uiColor: .light(Raw.hueStrain))
    /// `#8A6810` — ochre. Training load / ACWR.
    static let metricLoad      = Color(uiColor: .light(Raw.hueLoad))

    /// The canonical metric-hue set, in design-system order. The fence test reads this to assert
    /// the five hues are the only colors v6 added; keep it in sync with the tokens above.
    static let metricHues: [Color] = [
        metricReadiness, metricRecovery, metricSleep, metricStrain, metricLoad
    ]

    // MARK: - The Area Tint (v6.3 — HAN locked 2026-09-06, "warm and whisper")
    // The ONE sanctioned exception to "a metric hue never dresses a surface": each functional
    // area takes a WHISPER of its owning hue, so the hue an athlete is bathed in names the
    // metric family they are standing in. TWO formulas, no others, and both live here — a
    // hand-mixed color at a call site is a fence failure, not a style choice.
    //
    //   hero-plane wash : color-mix(in srgb, areaHue 4%,  plane)
    //   hairline tint   : color-mix(in srgb, areaHue 18%, divider)
    //
    // Mirrored byte-for-byte in `design-system/tokens/colors.css` (--area-*-plane /
    // --area-*-line); the canonical source and this iOS binding must agree.
    //
    // REJECTED at the same gate and NOT representable here: the cooled stone ramp, section-marker
    // squares, the area hue on the active tab tick (travertine keeps the live-state monopoly),
    // card washes beyond the hero plane, and any intensity above 4%/18%.
    //
    // Contrast is unaffected: a 4% wash moves plane luminance by less than a point, so every
    // measured floor in DESIGN.md still holds on the washed plane.

    /// The v6.3 hero-plane wash ratio. Fixed at 4% — a stronger wash was rejected at the gate.
    static let areaWashRatio: Double = 0.04
    /// The v6.3 hairline tint ratio. Fixed at 18% — a stronger tint was rejected at the gate.
    static let areaHairlineRatio: Double = 0.18

    /// The stone the area wash is mixed INTO. Only these two: a hero card's plane, and the
    /// bright top stop of a RAISED hero's gradient. There is no third — the tint never reaches
    /// the base plane, a well, or an ordinary (non-hero) card.
    enum AreaPlane {
        /// `surfaceEl` — the canonical card plane, and a flat hero's fill.
        case card
        /// `surfaceEl2` — the bright top stop of the `.raised` gradient.
        case raisedTop
    }

    /// The hue an area owns. Identical to that metric's identity token — the tint is the SAME
    /// hue at low strength, never a second, softer palette.
    static func areaHue(_ area: MetricArea) -> Color {
        Color(uiColor: .light(rawHue(area)))
    }

    /// The area's washed hero plane: `color-mix(in srgb, areaHue 4%, plane)`.
    /// The area's hero card only — never an ordinary card, never the page canvas.
    static func areaPlane(_ area: MetricArea, over plane: AreaPlane) -> Color {
        let base: UInt = switch plane {
        case .card:      Raw.planeCard
        case .raisedTop: Raw.planeRaisedTop
        }
        return mix(rawHue(area), into: base, ratio: areaWashRatio)
    }

    /// The area's tinted hairline: `color-mix(in srgb, areaHue 18%, divider)`.
    /// The area's structural rules — the masthead rule, section rules, in-card row separators.
    static func areaHairline(_ area: MetricArea) -> Color {
        mix(rawHue(area), into: Raw.rule, ratio: areaHairlineRatio)
    }

    private static func rawHue(_ area: MetricArea) -> UInt {
        switch area {
        case .readiness: Raw.hueReadiness
        case .recovery:  Raw.hueRecovery
        case .sleep:     Raw.hueSleep
        case .strain:    Raw.hueStrain
        case .load:      Raw.hueLoad
        }
    }

    /// sRGB linear interpolation, matching CSS `color-mix(in srgb, hue R%, base)` exactly:
    /// gamma-encoded channels, non-premultiplied, both operands opaque. This is the whole
    /// implementation of the area tint — there is deliberately nowhere else to write one.
    private static func mix(_ hue: UInt, into base: UInt, ratio: Double) -> Color {
        let r = CGFloat(ratio)
        func channel(shift: UInt) -> CGFloat {
            let hueValue  = CGFloat((hue  >> shift) & 0xFF)
            let baseValue = CGFloat((base >> shift) & 0xFF)
            return (hueValue * r + baseValue * (1 - r)) / 255
        }
        return Color(uiColor: UIColor(
            red:   channel(shift: 16),
            green: channel(shift: 8),
            blue:  channel(shift: 0),
            alpha: 1
        ))
    }

    // MARK: - Zone colors (v6 re-tune — label-led, supplementary only)
    // More chromatic than v5's near-grays (`#3F5A46`/`#6E5624`/`#7E362E`/`#46525E`, retired) for
    // gym-floor legibility. The Zone Color Rule is UNCHANGED: the text label carries the state
    // ("Optimal" / "Caution" / "High risk"), color is supplementary, NEVER color alone — and a
    // zone badge is text + hairline capsule, never a fill (nocebo guard).
    // Contrast: all four clear 4.5:1 on the CARD planes; `zoneOptimal` is 4.39:1 on the
    // `background` base plane, so zone-colored text below 24pt belongs on a card.
    /// `#2E7D4F` — verdant green (= `metricReadiness`).
    static let zoneOptimal  = Color(uiColor: .light(0x2E7D4F))
    /// `#8A5C08` — amber.
    static let zoneCaution  = Color(uiColor: .light(0x8A5C08))
    /// `#9E3428` — red.
    static let zoneDanger   = Color(uiColor: .light(0x9E3428))
    /// `#52589E` — indigo (= `metricSleep`); undertrained / neutral.
    static let zoneLow      = Color(uiColor: .light(0x52589E))

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
    /// `#E4E2DC` — hairline chart grid lines (v6). Grids are hairlines, never filled bands.
    static let chartGrid    = Color(uiColor: .light(0xE4E2DC))

    // v6 note for the adoption lanes: a series that carries a METRIC IDENTITY takes that
    // metric's hue (`metricRecovery` for HRV, `metricSleep` for sleep, `metricStrain` for acute
    // load, `metricLoad` for ACWR/chronic load). The warm-ink `chart*` tokens above remain for
    // series with NO metric identity. Re-pointing individual chart call sites is the Workload
    // (C) and Components (D) lanes' work, not the foundation's — the tokens exist for them.

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
