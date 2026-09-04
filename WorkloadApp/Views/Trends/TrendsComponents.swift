import SwiftUI
import Charts

// Shared trend/history sections, moved here verbatim from the retired tab files with the
// Trends merge (v1.7.3 reorientation slice 3): `LoadTrendChartView` + `PRHistorySection`
// from `WorkloadView.swift`, `WellnessHistorySection` from `RecoveryView.swift`.

// MARK: - Load Trend Chart

/// DESIGN.md v6 "Field Notes" — the load trend chart carries two series with a METRIC IDENTITY,
/// so each takes its hue: **ATL (acute load) → `metricStrain`** (rust) and
/// **CTL (chronic load) → `metricLoad`** (ochre). TSB is a derived balance with no metric identity
/// of its own, so its area keeps the identity-less warm-ink `chartTSB` token — which also keeps v6's
/// hard prohibition intact: a metric hue is never an area fill.
///
/// Grid hairlines are `chartGrid`; axis value labels render in the annotation voice (10pt Fragment
/// Mono via `AnnotationLabel`). The mono series key under the plot is the design system's own chart
/// grammar (`design-system/guidelines/charts.card.html` labels its series in mono): the DOT carries
/// the hue (a state dot — a sanctioned mark) while the key text stays `text3`.
struct LoadTrendChartView: View {
    @Environment(\.locale) private var locale
    let snapshots: [WorkloadSnapshot]
    @Binding var selectedDate: Date?

    /// Days the plotted snapshots actually span — the range control lets the athlete change it,
    /// so the axis stride has to be computed rather than assumed (v1.7.2 / audit L1).
    private var spanDays: Int {
        guard let first = snapshots.map(\.snapshotDate).min(),
              let last = snapshots.map(\.snapshotDate).max() else { return 1 }
        let calendar = Calendar.current
        return max(1, calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: first),
            to: calendar.startOfDay(for: last)
        ).day ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Chart {
                ForEach(snapshots, id: \.id) { snapshot in
                    // `series:` is load-bearing, not decoration. Swift Charts groups marks into
                    // series, and two `LineMark`s sharing the same x-values with NO series
                    // discriminator collapse into ONE series — so Charts connected ATL→CTL→ATL→CTL
                    // and drew a single zigzag in whichever style won, with the CTL line rendering
                    // nowhere. That predates v6 (it shipped with the warm-ink `chartATL`/`chartCTL`
                    // pair, where two near-identical inks made the artifact easy to miss); v6's
                    // distinct rust/ochre hues plus the series key below made it visible. Naming
                    // the series is what makes the two-hue mapping actually true on screen.
                    LineMark(
                        x: .value("Date", snapshot.snapshotDate),
                        y: .value("ATL", snapshot.acuteLoad),
                        series: .value("Series", "ATL")
                    )
                    .foregroundStyle(ColorTokens.metricStrain)

                    LineMark(
                        x: .value("Date", snapshot.snapshotDate),
                        y: .value("CTL", snapshot.chronicLoad),
                        series: .value("Series", "CTL")
                    )
                    .foregroundStyle(ColorTokens.metricLoad)

                    AreaMark(
                        x: .value("Date", snapshot.snapshotDate),
                        y: .value("TSB", snapshot.tsb)
                    )
                    .foregroundStyle(ColorTokens.chartTSB.opacity(0.2))
                }
            }
            .frame(height: 160)
            // No `.chartLegend` here (v1.7.2 / audit L10): it was a no-op. A legend needs a
            // `foregroundStyle(by:)` mapping to describe, and these series are styled directly;
            // the series key under the plot is hand-built in the annotation voice.
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: ChartAxisTicks.dayStride(spanningDays: spanDays))) { value in
                    AxisGridLine().foregroundStyle(ColorTokens.chartGrid)
                    AxisTick().foregroundStyle(ColorTokens.chartGrid)
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            AnnotationLabel(
                                date.formatted(.dateTime.month(.abbreviated).day().locale(locale)),
                                size: .small
                            )
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: ChartAxisTicks.yAxisStops)) { value in
                    AxisGridLine().foregroundStyle(ColorTokens.chartGrid)
                    AxisValueLabel {
                        if let load = value.as(Double.self) {
                            AnnotationLabel(String(format: "%.0f", load), size: .small)
                        }
                    }
                }
            }
            .id(locale)
            .entranceReveal()
            .chartOverlay { proxy in
                ChartTooltipGesture(
                    proxy: proxy,
                    data: snapshots.map { (date: $0.snapshotDate, value: $0.acuteLoad) },
                    selectedDate: $selectedDate
                )
            }
            .overlay(alignment: .top) {
                if let selectedDate,
                   let snapshot = snapshots.first(where: { Calendar.current.isDate($0.snapshotDate, inSameDayAs: selectedDate) }) {
                    TooltipBubble(
                        value: "ATL: \(String(format: "%.0f", snapshot.acuteLoad)) | CTL: \(String(format: "%.0f", snapshot.chronicLoad))",
                        dateLabel: snapshot.snapshotDate.formatted(.dateTime.month(.abbreviated).day().locale(locale))
                    )
                }
            }

            // Mono series key. ATL/CTL/TSB are the same untranslated scientific abbreviations the
            // metric grid above already prints verbatim, so this adds no new localizable copy.
            HStack(spacing: Spacing.sm) {
                seriesKey(glyph: "\u{25CF}", color: ColorTokens.metricStrain, label: "ATL", index: 0)
                seriesKey(glyph: "\u{25CF}", color: ColorTokens.metricLoad, label: "CTL", index: 1)
                seriesKey(glyph: "\u{2592}", color: ColorTokens.chartTSB, label: "TSB", index: 2)
                Spacer(minLength: 0)
            }
        }
    }

    /// One series-key cell: a hue-bearing state dot (`●`) or fill glyph (`▒`) plus its `text3`
    /// abbreviation, both in the annotation voice, revealed on the v6 choreography.
    private func seriesKey(glyph: String, color: Color, label: String, index: Int) -> some View {
        HStack(spacing: Spacing.baselinePair) {
            AnnotationLabel(glyph, size: .small, color: color)
                .accessibilityHidden(true)
            AnnotationLabel(label, size: .small)
        }
        .annotationReveal(index: index)
    }
}

// MARK: - PR History

struct PRHistorySection: View {
    let records: [PersonalRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.element.id) { index, pr in
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                        Text(pr.exerciseName)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                        Text(pr.recordType.displayName)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: Spacing.baselinePair) {
                        Text(String(format: "%.1f", pr.value))
                            .font(.Tokens.body)
                            .monospacedDigit()
                            .foregroundStyle(ColorTokens.text1)
                        if let improvement = pr.improvement {
                            // v6: a signed delta is marginalia — the annotation voice. It keeps
                            // its zone color and sits on a CARD plane, which is where rule 7
                            // requires sub-24pt zone-colored text to live.
                            AnnotationLabel(
                                String(format: "+%.1f", improvement),
                                color: ColorTokens.zoneOptimal
                            )
                        }
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)

                if index < records.count - 1 {
                    RowSeparator()
                }
            }
        }
        .cardStyle(horizontalPadding: 0, verticalPadding: 0)
    }
}

// MARK: - Wellness History

struct WellnessHistorySection: View {
    let checkIns: [WellnessCheckIn]
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(checkIns.enumerated()), id: \.element.id) { index, checkIn in
                HStack {
                    Text(checkIn.date.relativeString(locale: locale))
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                    Spacer()
                    Text("\(Int(checkIn.wellnessScore))/100")
                        .font(.Tokens.smallLabelMedium)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text1)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)

                if index < checkIns.count - 1 {
                    RowSeparator()
                }
            }
        }
        .cardStyle(horizontalPadding: 0, verticalPadding: 0)
    }
}
