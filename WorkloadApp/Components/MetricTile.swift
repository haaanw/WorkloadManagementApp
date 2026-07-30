import SwiftUI

/// Reusable metric display tile used across Workload and Session detail views.
///
/// v6 "Field Notes": the tile is a stone card carrying one reading. The two marginalia slots
/// — the metric key (`title`) and the qualifier (`subtitle`) — moved to the **annotation
/// voice** via `AnnotationLabel`, and they arrive on the v6 choreography (`.annotationReveal`)
/// so the card settles first and the labels land after it. The value stays in the **working
/// voice** with tabular figures (`smallLabelMedium` + `.monospacedDigit()`) — a value is
/// something the app *says*, not something it annotates.
///
/// **`color` is the metric-hue channel.** Pass the owning metric's hue
/// (`ColorTokens.metricStrain` for acute load, `.metricLoad` for chronic/ACWR,
/// `.metricRecovery` for HRV, `.metricSleep` for sleep, `.metricReadiness` for readiness) and
/// the reading carries its identity without a legend. Defaults to `text1` for readings with no
/// metric identity. Because the tile applies `.cardStyle()` itself, a hue-colored value below
/// 24pt always lands on a **card plane** — which is what DESIGN.md rule 7 requires.
struct MetricTile: View {
    let title: String
    let value: String
    var subtitle: String?
    /// The reading's metric hue (see the type doc). `text1` = no metric identity.
    var color: Color = ColorTokens.text1

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            AnnotationLabel(title, size: .small)
                .annotationReveal(index: 0)
            Text(value)
                .font(.Tokens.smallLabelMedium)
                .monospacedDigit()
                .foregroundStyle(color)
            if let subtitle {
                AnnotationLabel(subtitle, size: .small, color: ColorTokens.text2)
                    .annotationReveal(index: 1)
            }
        }
        .cardStyle(horizontalPadding: Spacing.sm, verticalPadding: Spacing.sm)
    }
}

/// Hairline-bordered text-first chip communicating zone state (v5 Corner Law: chips and
/// badges wear the pill — `Capsule()`, `CornerTokens.pill`). Zone color appears as TEXT +
/// border only, **never as a zone-colored fill**; the text label is always the primary
/// information (color supplementary — never color alone). That is the nocebo guard, and v6
/// leaves it untouched.
///
/// The label stays in the **working voice** (`micro`, 11pt Instrument Sans) — "Optimal" is
/// something the app *says* about the athlete's state, not marginalia. It is deliberately NOT
/// `AnnotationLabel`; the design system's own `ZoneBadge` reference renders `--font-sans` too.
///
/// **v6 contrast law (DESIGN.md rule 7):** zone-colored text below 24pt must sit on a card
/// plane — `zoneOptimal` measures 4.39:1 on the `background` scroll canvas (below the 4.5:1
/// small-text floor) but 4.71:1 on `surfaceEl` and 4.85:1 on `surfaceEl2`. The badge therefore
/// carries its **own** `surfaceEl2` capsule backing rather than trusting whatever plane a call
/// site drops it on: on an emphasis card the fill is a no-op, on a standard card it is a 4/255
/// lift (imperceptible, and it reads as the raised chip the Relief Law asks for), and on the
/// bare canvas it is what keeps the badge legal. The fill is stone, never the zone color.
///
/// zh-Hans typography: per 23-UI-SPEC, Chinese has no case and looser tracking is wrong, so
/// the case transform and tracking are Latin-only (`isLatin`, the same idiom as
/// `AnnotationLabel` / `MetricCell` / `RuledSectionHeader` — v6 fixed this from an `== "en"`
/// test that wrongly excluded French). Horizontal padding widens for zh-Hans glyphs (16 vs 8).
/// Paddings sit on the 8pt grid (+ the sanctioned 4pt sub-step).
struct ZoneBadge: View {
    @Environment(\.locale) private var locale
    let label: String
    let color: Color

    private var isLatin: Bool { locale.language.languageCode?.identifier != "zh" }

    var body: some View {
        Text(label)
            .font(.Tokens.micro)
            .tracking(isLatin ? 1.2 : 0)
            .textCase(isLatin ? .uppercase : nil)
            .padding(.horizontal, isLatin ? 8 : 16)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(ColorTokens.surfaceEl2, in: Capsule())
            .overlay(
                Capsule().stroke(color, lineWidth: 0.5)
            )
    }
}
