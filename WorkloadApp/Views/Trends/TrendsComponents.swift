import SwiftUI
import Charts

// Shared trend/history sections, moved here verbatim from the retired tab files with the
// Trends merge (v1.7.3 reorientation slice 3): `LoadTrendChartView` + `PRHistorySection`
// from `WorkloadView.swift`, `WellnessHistorySection` from `RecoveryView.swift`.
//
// The three sections at the top of this file are new with the v1.7.3 re-scope (UAT round 1 ·
// U9): the fatigue hero, the load read, and the activity read. Everything below them is
// carried over unchanged.

// MARK: - Range rail

/// The page's spine: 1 week / 2 weeks / 1 month.
///
/// Shaped as a RAIL rather than a segmented control, matching the Log tab's
/// `SessionTypeFilterBar` — it sits in the same place on the screen and does the same job, and
/// two filter rails one tab apart that look different is the kind of drift this release is
/// closing. The active item takes an INK underline: v5 gives chrome selection to ink and keeps
/// travertine for live-state marks.
///
/// (`Components/TimeRangeSegmentedControl.swift` was this control's previous form and now has
/// no caller. Left in place rather than deleted — removing a file is a `.pbxproj` edit, which
/// is serialized across lanes.)
struct TrendsRangeRail: View {
    @Binding var selected: TimeRange
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases) { range in
                Button {
                    guard selected != range else { return }
                    Haptics.select()
                    withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                        selected = range
                    }
                } label: {
                    Text(range.label)
                        .font(selected == range ? .Tokens.smallLabelMedium : .Tokens.smallLabel)
                        .foregroundStyle(selected == range ? ColorTokens.text1 : ColorTokens.text2)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .overlay(alignment: .bottom) {
                            if selected == range {
                                Rectangle()
                                    .fill(ColorTokens.text1)
                                    .frame(height: 1.5)
                                    .padding(.horizontal, Spacing.sm)
                            }
                        }
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(selected == range ? [.isButton, .isSelected] : .isButton)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.sm)
        .frame(height: 40)
        .background(ColorTokens.background)
        .accessibilityIdentifier("trends.rangeRail")
    }
}

// MARK: - Fatigue (the page's hero)

/// Accumulated fatigue across the window: the index as a hero reading in the load hue, its zone
/// as a hairline capsule, the accumulation chart, one trajectory sentence in the working voice,
/// and the engine's own component decomposition as an annotation reason tree.
///
/// ## Claim rails (U9, HAN)
///
/// Everything this section says is a DESCRIPTION of values the app already holds: where the
/// index started and where it is now, how many recent days it has not come down, and what the
/// six component scores were. It never names an injury risk, never forecasts, and never
/// prescribes — Trends describes, and the day's proposal on Today decides. Under
/// `FatigueHistoryEngine.minimumHistoryDays` it draws no chart and says how much history it has
/// instead of guessing.
struct TrendsFatigueSection: View {
    let points: [FatigueHistoryEngine.Point]
    let trajectory: FatigueHistoryEngine.Trajectory?
    let daysWithoutRelief: Int
    let observedHistoryDays: Int
    let hasEnoughHistory: Bool
    let rangeDays: Int

    @Environment(\.locale) private var locale

    private var latest: FatigueHistoryEngine.Point? { points.last }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasEnoughHistory, let latest {
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        // The hero reading, in the LOAD hue. `displayAction` is 32pt — the
                        // floor at which DESIGN.md allows a hue-coloured reading on any plane
                        // — and it sits on the hero card anyway (Reading Color Rule v6).
                        Text("\(Int(latest.index.rounded()))")
                            .font(.Tokens.displayAction)
                            .monospacedDigit()
                            .foregroundStyle(ColorTokens.metricLoad)
                        AnnotationLabel(key: "trends.fatigue.unit", size: .small)
                            .annotationReveal()
                    }
                    Spacer()
                    // Text label first, colour supplementary — the Zone Color Rule. A hairline
                    // capsule, never a fill.
                    ZoneBadge(
                        label: Self.zoneLabel(latest.zone, locale: locale),
                        color: ColorTokens.fatigueZoneColor(latest.zone)
                    )
                }

                FatigueAccumulationChart(points: points)

                Text(trajectorySentence)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.sm)

                VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                    ForEach(Array(componentRows.enumerated()), id: \.offset) { index, row in
                        AnnotationLabel(row, size: .small)
                            .annotationReveal(index: index)
                    }
                }
                .padding(.top, Spacing.sm)
            } else {
                Text(String(
                    format: LocalePinnedStrings.localized("trends.fatigue.empty", locale: locale),
                    observedHistoryDays,
                    FatigueHistoryEngine.minimumHistoryDays
                ))
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        // The one card on this page that takes the area's 4% wash.
        .cardStyle(isHero: true)
        .accessibilityIdentifier("trends.fatigue")
    }

    /// The window's story in one or two sentences, both readings of stored values.
    private var trajectorySentence: String {
        guard let first = points.first, let latest else { return "" }
        let from = Int(first.index.rounded())
        let to = Int(latest.index.rounded())

        // A steady window gets its own sentence rather than "moved from 48 to 49" — the number
        // did not move, and saying it did would be a claim the series does not support.
        var sentence: String
        if trajectory == .steady {
            sentence = String(
                format: LocalePinnedStrings.localized("trends.fatigue.sentence.held", locale: locale),
                to, rangeDays
            )
        } else {
            sentence = String(
                format: LocalePinnedStrings.localized("trends.fatigue.sentence.moved", locale: locale),
                from, to, rangeDays
            )
        }

        if daysWithoutRelief > 0 {
            sentence += " " + String(
                format: LocalePinnedStrings.localized("trends.fatigue.sentence.noRelief", locale: locale),
                daysWithoutRelief
            )
        }
        return sentence
    }

    /// The engine's own six components, complete. All six rather than the movers only: a
    /// partial decomposition would misreport what built the number.
    ///
    /// The names are resolved from LITERAL keys, not from a `[String]` of key names — a runtime
    /// string cannot be a `String.LocalizationValue`, and the paired arrays keep the six names
    /// and the six scores in one visible order.
    private var componentRows: [String] {
        guard let components = latest?.components else { return [] }
        let names = [
            LocalePinnedStrings.localized("trends.fatigue.component.loadElevation", locale: locale),
            LocalePinnedStrings.localized("trends.fatigue.component.sessionDensity", locale: locale),
            LocalePinnedStrings.localized("trends.fatigue.component.restDebt", locale: locale),
            LocalePinnedStrings.localized("trends.fatigue.component.recoveryTrend", locale: locale),
            LocalePinnedStrings.localized("trends.fatigue.component.wellnessTrend", locale: locale),
            LocalePinnedStrings.localized("trends.fatigue.component.softTissue", locale: locale)
        ]
        let scores = [
            components.loadElevation,
            components.sessionDensity,
            components.restDebt,
            components.recoveryTrend,
            components.wellnessTrend,
            components.softTissueRisk
        ]
        return zip(names, scores).enumerated().map { index, row in
            let branch = index == names.count - 1 ? "\u{2514}\u{2500}" : "\u{251C}\u{2500}"
            return "\(branch) \(row.0) \(Self.componentGlyph(row.1)) \(Int((row.1 * 100).rounded()))"
        }
    }

    /// `▲` above the neutral 0.5, `▼` below it, `●` at it — DESIGN.md's glyph set. Ink, never a
    /// zone colour: a component above neutral is a reading, not a diagnosis.
    private static func componentGlyph(_ score: Double) -> String {
        if score > 0.55 { return "\u{25B2}" }
        if score < 0.45 { return "\u{25BC}" }
        return "\u{25CF}"
    }

    /// The zone in words. `FatigueZone.displayName` is an untranslated English literal used for
    /// diagnostics; a badge an athlete reads takes a localized key.
    static func zoneLabel(_ zone: FatigueIndexEngine.FatigueZone, locale: Locale) -> String {
        switch zone {
        case .low:        LocalePinnedStrings.localized("trends.fatigue.zone.low", locale: locale)
        case .elevated:   LocalePinnedStrings.localized("trends.fatigue.zone.elevated", locale: locale)
        case .high:       LocalePinnedStrings.localized("trends.fatigue.zone.high", locale: locale)
        case .saturation: LocalePinnedStrings.localized("trends.fatigue.zone.veryHigh", locale: locale)
        }
    }
}

/// The accumulation plot: one line, in the load hue, over the window.
///
/// **No area fill under the line**, and that is deliberate rather than an omission. The gated
/// demo draws one; DESIGN.md forbids a metric hue as a plane fill outright, and this app already
/// held that line once — `HRVDetailChart` documents refusing a hue-filled ±1SD band for the same
/// reason, and `LoadTrendChartView`'s TSB wash uses the identity-less `chartTSB` ink to stay
/// inside the rule. A line carries the accumulation on its own.
struct FatigueAccumulationChart: View {
    @Environment(\.locale) private var locale
    let points: [FatigueHistoryEngine.Point]

    /// Days the series spans — the axis stride has to be computed, because the rail changes it.
    private var spanDays: Int {
        guard let first = points.first?.day, let last = points.last?.day else { return 1 }
        return max(1, Calendar.current.dateComponents([.day], from: first, to: last).day ?? 1)
    }

    var body: some View {
        Chart {
            ForEach(points, id: \.day) { point in
                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Fatigue", point.index)
                )
                .foregroundStyle(ColorTokens.metricLoad)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .frame(height: 120)
        .chartYScale(domain: 0...100)
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
                    if let index = value.as(Double.self) {
                        AnnotationLabel(String(format: "%.0f", index), size: .small)
                    }
                }
            }
        }
        .id(locale)
        .padding(.top, Spacing.sm)
        .entranceReveal()
    }
}

// MARK: - Load

/// Acute ÷ chronic over the window, with the range the athlete has actually held stated in
/// words. The held range is a SENTENCE rather than the demo's shaded band: a zone-hued band
/// behind a plot is a hue dressing a surface, and a range is unambiguous stated.
struct TrendsLoadSection: View {
    let snapshot: WorkloadSnapshot?
    let acwrRange: (low: Double, high: Double)?
    let trendSnapshots: [WorkloadSnapshot]
    @Binding var selectedTrendDate: Date?

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let snapshot {
                HStack(alignment: .firstTextBaseline) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text(String(format: "%.2f", snapshot.acwr))
                            .font(.Tokens.displayAction)
                            .monospacedDigit()
                            .foregroundStyle(ColorTokens.text1)
                        AnnotationLabel(key: "trends.load.unit", size: .small)
                            .annotationReveal()
                    }
                    Spacer()
                    ZoneBadge(
                        label: snapshot.zone.displayName,
                        color: ColorTokens.acwrZoneColor(snapshot.zone)
                    )
                }
            }

            if trendSnapshots.count > 1 {
                LoadTrendChartView(snapshots: trendSnapshots, selectedDate: $selectedTrendDate)
                    .padding(.top, Spacing.sm)
            } else {
                // Say WHY there is no chart (v1.7.2 / audit M10) — a young history, not a
                // rendering failure.
                Text("workload.chart.insufficientData")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.top, Spacing.sm)
            }

            if let sentence = loadSentence {
                Text(sentence)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Spacing.sm)
            }
        }
        .cardStyle()
        .accessibilityIdentifier("trends.loadTrend")
    }

    /// A ratio and its own history — both readings of stored values.
    private var loadSentence: String? {
        guard let snapshot else { return nil }
        var sentence = String(
            format: LocalePinnedStrings.localized("trends.load.sentence", locale: locale),
            String(format: "%.2f", snapshot.acwr)
        )
        if let acwrRange, acwrRange.high > acwrRange.low {
            sentence += " " + String(
                format: LocalePinnedStrings.localized("trends.load.sentence.heldRange", locale: locale),
                String(format: "%.2f", acwrRange.low),
                String(format: "%.2f", acwrRange.high)
            )
        }
        return sentence
    }
}

// MARK: - What you did

/// Sessions across the window against the athlete's OWN average, one bar per day. Counts and
/// stored training-stress values only — no comparison to anybody else, and no judgement.
struct TrendsWhatYouDidSection: View {
    let sessionCount: Int
    let baselineSessions: Double?
    let bars: [(date: Date, load: Double)]
    let typeCounts: [(type: SessionType, count: Int)]
    let rangeDays: Int

    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text("\(sessionCount)")
                    .font(.Tokens.displayAction)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.text1)
                AnnotationLabel(
                    String(
                        format: LocalePinnedStrings.localized("trends.activity.unit", locale: locale),
                        rangeDays
                    ),
                    size: .small
                )
                .annotationReveal()
            }

            if sessionCount > 0 {
                DailyLoadBars(bars: bars)

                if let sentence = baselineSentence {
                    Text(sentence)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Spacing.sm)
                }

                if !typeCounts.isEmpty {
                    AnnotationLabel(breakdown, size: .small)
                        .annotationReveal(index: 1)
                        .padding(.top, Spacing.baselinePair)
                }
            } else {
                Text("trends.activity.empty")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.top, Spacing.sm)
            }
        }
        .cardStyle()
        .accessibilityIdentifier("trends.activity")
    }

    private var baselineSentence: String? {
        guard let baselineSessions else { return nil }
        return String(
            format: LocalePinnedStrings.localized("trends.activity.sentence.baseline", locale: locale),
            rangeDays,
            String(format: "%.0f", baselineSessions.rounded())
        )
    }

    /// `STRENGTH 5 · SKILL 3 · CONDITIONING 1` — counts, in the annotation voice. The type
    /// names come from the enum's own display names, so the key set never drifts from it.
    private var breakdown: String {
        typeCounts
            .map { "\($0.type.displayName) \($0.count)" }
            .joined(separator: " \u{00B7} ")
    }
}

/// One bar per day of the window: that day's summed training stress. Rest days are drawn as
/// present-and-zero, so the rhythm of a week reads off the plot rather than being inferred from
/// gaps. `BarMark` in a metric hue is the shipped idiom (`SleepTrendChart`) — a bar is a datum,
/// not a plane.
struct DailyLoadBars: View {
    let bars: [(date: Date, load: Double)]

    var body: some View {
        Chart {
            ForEach(bars, id: \.date) { bar in
                BarMark(
                    x: .value("Day", bar.date, unit: .day),
                    y: .value("Load", bar.load)
                )
                .foregroundStyle(ColorTokens.metricLoad)
                .opacity(0.5)
            }
        }
        .frame(height: 56)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .padding(.top, Spacing.sm)
        .entranceReveal()
    }
}

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
