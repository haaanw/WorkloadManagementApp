import SwiftUI

// v4.1 layout-recomposition primitives (owned by workstream WS2 — see
// .planning/orchestration/2026-07-20-v41-handoff.md). Pre-registered stub:
// the orchestrator created this file so parallel sessions never edit pbxproj.
//
// The demo §3 "After" composition (`.planning/design-reference/tuwa-v4-polish-demos.html`)
// asks every screen for the same two compositional moves: a scannable METRIC GRID (a row of
// baseline-aligned dial readouts, each with a unit superscript and an optional delta line)
// and RULED SECTION HEADERS (micro-caps that carry a trailing hairline so they structure the
// page instead of floating). Both live here so the five recomposed tabs share one grammar.
//
// All values route through ColorTokens / Font.Tokens / Spacing / CornerTokens — no literals.

// MARK: - Metric cell

/// One cell of the demo-§3 metric grid: a micro-caps label, a dial-voice value with an
/// optional unit superscript, and an optional bottom accessory (a delta line, a staleness
/// badge, anything the caller supplies). Designed to sit in an equal-width `HStack` so a row
/// of cells reads as a scannable grid.
///
/// FIXED-width behaviour (D13-c / the handoff's fixed-width rule): the value renders in the
/// dial voice (IBM Plex Mono — tabular by construction) with `.monospacedDigit()`, and the
/// cell fills its share of the row via `maxWidth: .infinity`. A cell therefore never resizes
/// when its digit count changes — 58 and 148 occupy the same box — so a re-measure never
/// reflows the grid.
struct MetricCell<Accessory: View>: View {
    let label: String
    let value: String
    var unit: String?
    var valueColor: Color
    private let accessory: Accessory

    @Environment(\.locale) private var locale
    private var isLatin: Bool { locale.language.languageCode?.identifier != "zh" }

    init(
        label: String,
        value: String,
        unit: String? = nil,
        valueColor: Color = ColorTokens.text1,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.label = label
        self.value = value
        self.unit = unit
        self.valueColor = valueColor
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.Tokens.micro)
                .tracking(isLatin ? 1.2 : 0)
                .textCase(isLatin ? .uppercase : nil)
                .foregroundStyle(ColorTokens.text3)
                .lineLimit(1)

            Spacer().frame(height: Spacing.xs)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.baselinePair) {
                Text(value)
                    .font(.Tokens.dialValue)
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit)
                        .font(.Tokens.micro)
                        .foregroundStyle(ColorTokens.text3)
                        .lineLimit(1)
                }
            }

            accessory
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dataPlate(horizontalPadding: Spacing.sm, verticalPadding: Spacing.sm)
    }
}

/// The default metric-cell accessory: the demo's mono-ish delta line (`−3% vs base`). Renders
/// nothing when `text` is nil, so a cell with no delta collapses to label + value cleanly.
/// The copy is mixed (numerals + words), so it stays in the UI voice per the Two-Voice law —
/// the dial voice is numerals/units only.
struct MetricDeltaLine: View {
    let text: String?

    var body: some View {
        if let text {
            Spacer().frame(height: Spacing.baselinePair)
            Text(text)
                .font(.Tokens.micro)
                .foregroundStyle(ColorTokens.text3)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

extension MetricCell where Accessory == MetricDeltaLine {
    /// Convenience: a metric cell whose bottom slot is the standard delta line (or empty).
    init(
        label: String,
        value: String,
        unit: String? = nil,
        valueColor: Color = ColorTokens.text1,
        delta: String? = nil
    ) {
        self.init(label: label, value: value, unit: unit, valueColor: valueColor) {
            MetricDeltaLine(text: delta)
        }
    }
}

// MARK: - Ruled section header

/// The demo-§3 ruled section header: a micro-caps label followed by a 0.5pt hairline rule
/// that runs to the trailing edge. Unlike `SectionHeader` (19pt Medium), this is the quiet
/// structural divider between zones of one screen — it groups without shouting.
///
/// Carries NO horizontal padding of its own: callers place it inside an already-inset column
/// so the rule aligns flush with the cards beneath it. Tracking/casing are Latin-only (CJK
/// has no case and looser tracking is wrong — same rule as `ScreenHeader`).
struct RuledSectionHeader: View {
    let title: LocalizedStringKey

    @Environment(\.locale) private var locale
    private var isLatin: Bool { locale.language.languageCode?.identifier != "zh" }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            Text(title)
                .font(.Tokens.micro)
                .tracking(isLatin ? 1.6 : 0)
                .textCase(isLatin ? .uppercase : nil)
                .foregroundStyle(ColorTokens.text2)
                .fixedSize(horizontal: true, vertical: false)
            Rectangle()
                .fill(ColorTokens.dividerStrong)
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
    }
}
