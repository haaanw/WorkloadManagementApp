import SwiftUI

// MARK: - Chart detail primitives (v6 "Field Notes", Session H)
//
// The zoomed chart screens (`SleepDetailView`, `HRVDetailView`) share four pieces of furniture
// that the *glance* cards deliberately do not have: a persistent readout well, a plot key, a
// reason tree, and expandable explanations. They live here rather than in either screen so the
// two screens cannot drift apart, and so the glance chart components stay untouched.

/// A section eyebrow in the **working voice** — a head the app *says*, not a machine key.
///
/// Exists because the detail screens were applying `.tracking(0.9)` to their eyebrows with no
/// locale guard, which put Latin letter-spacing on Chinese text (DESIGN.md: "zh-Hans gets no case
/// transform and no added tracking"). Centralising it means neither screen can reintroduce the
/// bug, and matches how `ScreenHeader` and `AnnotationLabel` already handle the same question.
struct SectionEyebrow: View {
    let key: LocalizedStringKey

    @Environment(\.locale) private var locale
    private var isLatin: Bool { locale.language.languageCode?.identifier != "zh" }

    var body: some View {
        Text(key)
            .font(.Tokens.micro)
            .tracking(isLatin ? 0.9 : 0)
            .textCase(isLatin ? .uppercase : nil)
            .foregroundStyle(ColorTokens.text3)
    }
}

// MARK: - Readout well

/// **Primitive 3 · Detent control** — the fixed-width debossed well that reports the scrubbed day.
///
/// A day-by-day chart scrub is a discrete detent traverse, so its reading belongs in a readout
/// well and the digit change rides `Motion.digitRoll` ("~100ms digit-roll, fixed-width readout
/// wells"). The well is **always present**: with no selection it reports the most recent day,
/// stamped `● NOW`. It never appears or disappears — "digits change, the stone never resizes".
///
/// Nothing here wears a metric hue. The well is `wellTop→wellBottom`, not a card plane, and
/// DESIGN.md contrast rule 7 confines hue/zone text below 24pt to card planes and bans `text3`
/// annotation on a well outright (2.84:1). So the reading is `text1` ink and its marginalia is
/// `text2`. The hue lives on the plot key and the series, where it is legal.
struct ChartReadoutWell: View {
    /// `SUN 07.27` or `● NOW` — an annotation timestamp, never a sentence.
    let dayStamp: String
    /// The reading itself, working voice, tabular.
    let value: String
    /// Signed delta against the screen's reference (`▲ +13.7% VS BASE`). Nil when undefined.
    let delta: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: Spacing.xs) {
            AnnotationLabel(dayStamp, size: .small, color: ColorTokens.text2)
            Spacer(minLength: Spacing.xs)
            Text(value)
                .font(.Tokens.body)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
            if let delta {
                AnnotationLabel(delta, size: .small, color: ColorTokens.text2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .debossed(cornerRadius: CornerTokens.control)
        .animation(Motion.resolved(Motion.digitRoll, reduceMotion: reduceMotion), value: value)
    }
}

// MARK: - Plot key

/// One cell of a plot key.
///
/// `swatch` is **non-nil only when the cell keys a mark the plot actually draws**. The sleep key
/// has three cells but the plot draws two rules, so the middle cell carries no swatch: a key
/// advertising a mark that does not exist is the exact defect Wave 2 found in `LoadTrendChartView`
/// (a series key for a series that was never drawn), and repeating it here would be worse for
/// knowing about it.
struct ChartKeyCell {
    /// The colour of the mark this cell keys — or nil when the cell only names a range.
    let swatch: Color?
    let rangeKey: LocalizedStringKey
    let stateKey: LocalizedStringKey
}

/// The key that sits **above** the plot (never inside it — v6.1, HAN 2026-07-30: an in-plot
/// `.annotation` on a rule mark lands on the data it describes and both become unreadable).
///
/// Colour rides the `▒` swatch glyph and the label stays `text3`. That is the
/// `LoadTrendChartView.seriesKey` precedent, and it means the key needs no card-plane contrast
/// exemption for coloured text. The state is named in words, so colour is supplementary and never
/// the sole carrier (DESIGN.md rule 6).
struct ChartPlotKey: View {
    let cells: [ChartKeyCell]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.sm) {
                cellViews
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                cellViews
            }
        }
    }

    @ViewBuilder
    private var cellViews: some View {
        ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
            HStack(spacing: Spacing.baselinePair) {
                if let swatch = cell.swatch {
                    // ▒ — DESIGN.md's sanctioned "fills / sufficiency" glyph. Decorative to a
                    // screen reader, so it is hidden from accessibility; the range and state
                    // labels carry the whole meaning.
                    AnnotationLabel("\u{2592}", size: .small, color: swatch)
                        .accessibilityHidden(true)
                }
                AnnotationLabel(key: cell.rangeKey, size: .small)
                AnnotationLabel("\u{00B7}", size: .small)
                AnnotationLabel(key: cell.stateKey, size: .small)
            }
            .annotationReveal(index: index)
        }
    }
}

// MARK: - Reason tree

/// The `├─ └─` reason tree — "where the annotation voice earns its keep".
///
/// One unbroken stem per tree, with no working-voice heading interleaved between rows: Wave 2
/// found Home's tree split across headings so it read as two fragments rather than one derivation.
/// The head above the tree IS working voice (a head is something the app *says*); the rows are
/// annotation. Rows take `text2`, not `text3` — a reason tree is the reasoning itself, which
/// DESIGN.md contrast rule 4 puts above the marginalia floor.
///
/// The block sits on `surfaceEl`, a card plane, so a hued token inside it would be legal. Nothing
/// here is hued: HAN's Q4 ruling is all ink, no fill.
struct ReasonTreeSection: View {
    let headKey: LocalizedStringKey
    let rows: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionEyebrow(key: headKey)
            VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    AnnotationLabel(stem(at: index) + row, color: ColorTokens.text2)
                        .annotationReveal(index: index)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.surfaceEl)
    }

    /// `└─` closes whichever row ends up last — rows are suppressed individually upstream when
    /// their input is missing, so the stem is computed rather than authored.
    private func stem(at index: Int) -> String {
        index == rows.count - 1 ? "\u{2514}\u{2500} " : "\u{251C}\u{2500} "
    }
}

// MARK: - Expandable explanations

/// One collapsed explanation: a working-voice title and a working-voice body. Never annotation —
/// DESIGN.md rule 9, "annotation is never a sentence".
struct DetailDisclosureItem {
    let titleKey: LocalizedStringKey
    let bodyKey: LocalizedStringKey
}

/// The About block: an eyebrow over N disclosure rows, all collapsed by default (progressive
/// disclosure — the chart and the tree answer the question; the prose is for the curious).
///
/// **Primitive 2 · Row.** It discloses rather than commits, so it takes the Row press — the
/// `text1`@6% background well via `.rowWell`, no scale — and not the opacity dip some older
/// disclosures in this repo use. That older grammar is a known deviation from the Five-Primitive
/// Law; propagating it into new code would make it harder to fix at its source.
struct DetailDisclosureList: View {
    let eyebrowKey: LocalizedStringKey
    let items: [DetailDisclosureItem]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SectionEyebrow(key: eyebrowKey)
                .padding(.horizontal, Spacing.sm)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    disclosureRow(index: index, item: item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private func disclosureRow(index: Int, item: DetailDisclosureItem) -> some View {
        let isExpanded = expanded.contains(index)

        Button {
            Haptics.tap()
            withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                if isExpanded {
                    expanded.remove(index)
                } else {
                    expanded.insert(index)
                }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(item.titleKey)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.Tokens.micro)
                    .foregroundStyle(ColorTokens.text3)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.rowWell(cornerRadius: CornerTokens.control))
        .accessibilityAddTraits(.isButton)

        if isExpanded {
            Text(item.bodyKey)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.sm)
                .padding(.bottom, Spacing.sm)
        }
    }
}

// MARK: - Axis ticks (v1.7.2 audit — L1 / L2)

/// Tick spacing for the app's charts.
///
/// Swift Charts' automatic date axis picks a stride from the plot width, not from the data's
/// span, so a dense 28-day series drew repeated labels — "AUG 4" three times in a row, which
/// reads as a rendering bug rather than as a busy axis. And an automatic y-axis on a tight
/// domain hands back non-integer stops that the `%.0f` formatter rounds into duplicates
/// ("62, 62, 63"). Both are the same defect: the axis was left to guess.
enum ChartAxisTicks {

    /// Day stride that keeps a date axis to at most `maxLabels` labels.
    ///
    /// Five is the ceiling because the labels are 10pt uppercase mono with tracking, and a
    /// 28-day span at 350pt fits about that many before they touch.
    static func dayStride(spanningDays: Int, maxLabels: Int = 5) -> Int {
        guard spanningDays > 0 else { return 1 }
        return max(1, Int((Double(spanningDays) / Double(maxLabels)).rounded(.up)))
    }

    /// How many y-axis stops to ask for. Deliberately few: these are glance charts, and a
    /// sparse axis is what stops the `%.0f` rounding from producing two identical labels.
    static let yAxisStops = 4
}
