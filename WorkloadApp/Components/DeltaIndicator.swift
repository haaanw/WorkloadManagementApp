import SwiftUI

/// Week-over-week delta mark (D-04).
///
/// v6 "Field Notes": a delta is pure marginalia, so it renders in the **annotation voice** with
/// the sanctioned Unicode glyph set instead of an SF Symbol arrow — `▲ ▼` for a significant
/// move, `△ ▽` for a mild one, `=` for flat. Unicode *is* the icon system here (no icon font,
/// no emoji, ever), and the glyph plus the signed number means the direction is never carried
/// by colour alone.
///
/// Colour follows the design system's `DeltaIndicator` reference: favourable → `zoneOptimal`,
/// unfavourable → `zoneCaution`, flat → `text3`. Caution rather than danger is deliberate — a
/// week-over-week dip is not an alarm, and the brand voice is "never alarmist, never punitive".
///
/// **Contrast:** zone-coloured text below 24pt must sit on a card plane (DESIGN.md rule 7).
/// This mark is designed for the inside of a card; do not place it on the bare scroll canvas.
struct DeltaIndicator: View {
    /// Percentage value (e.g. `12.0` = +12%).
    let delta: Double
    /// Whether an increase is the favourable direction. `false` for metrics where lower is
    /// better (resting heart rate, for instance).
    var goodIsUp: Bool = true
    /// Magnitude at or above which the glyph fills (`▲`) rather than outlines (`△`).
    var significantThreshold: Double = 3.0

    private var isFlat: Bool { abs(delta) < 1.0 }
    private var isUp: Bool { delta > 0 }
    private var isSignificant: Bool { abs(delta) >= significantThreshold }

    private var glyph: String {
        if isFlat { return "=" }
        if isUp { return isSignificant ? "\u{25B2}" : "\u{25B3}" }   // ▲ △
        return isSignificant ? "\u{25BC}" : "\u{25BD}"               // ▼ ▽
    }

    private var color: Color {
        if isFlat { return ColorTokens.text3 }
        return isUp == goodIsUp ? ColorTokens.zoneOptimal : ColorTokens.zoneCaution
    }

    var body: some View {
        if isFlat {
            // a11y strings stay verbatim English, matching this file's pre-v6 convention —
            // introducing new xcstrings keys is a copy change, which this restyle does not make.
            AnnotationLabel(glyph, color: color)
                .accessibilityLabel("Unchanged week over week")
        } else {
            AnnotationLabel(String(format: "%@ %+.0f%%", glyph, delta), color: color)
                .accessibilityLabel(delta > 0
                    ? "Increased \(Int(abs(delta))) percent week over week"
                    : "Decreased \(Int(abs(delta))) percent week over week")
        }
    }
}
