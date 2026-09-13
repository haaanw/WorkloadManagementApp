import SwiftUI
import Charts

/// The zoomed resting-heart-rate screen — the third of Today's three metric cells to get a
/// destination (v1.7.3 · UAT round 1 · U9).
///
/// Same grammar as `HRVDetailView` and `SleepDetailView`, deliberately: context stamp → title →
/// stats band → scrubbable plot + persistent readout well → reason tree → expandable
/// explanations. Three cells that look alike must behave alike; a third screen inventing its own
/// shape would make the strip's uniformity a lie.
///
/// **What is genuinely different, and it is one thing: direction.** For HRV a fall below baseline
/// is the signal; for resting heart rate it is a RISE. Nothing here colours that — the deviation
/// is reported signed, the glyph is ink, and the About section says in words which way is which.
/// A red number on an elevated RHR would be a diagnosis the engine cannot support, which is
/// exactly the pressure the nocebo guard exists to prevent.
struct RHRDetailView: View {
    /// One value per calendar day — the all-day reduction, no morning filter. See
    /// `RHRDailyStats` for why RHR and HRV bucket differently.
    let data: [(date: Date, value: Double)]

    @Environment(\.locale) private var locale
    @State private var selectedDate: Date?
    /// Visible plot window in days, driven by the two-finger pinch on the chart.
    @State private var windowDays: Int = 28
    @State private var pinchBaseWindow: Int?

    private var dailyValues: [RHRDailyStats.DailyValue] {
        data.map { RHRDailyStats.DailyValue(date: $0.date, value: $0.value) }
    }

    private var availability: RHRDailyStats.Availability {
        RHRDailyStats.availability(daily: dailyValues)
    }

    private var latest: Double? { RHRDailyStats.latest(dailyValues)?.value }

    /// Nil until there are enough PRIOR days — a baseline that contains the day being compared
    /// against it reads a permanent, meaningless 0%.
    private var sevenDayAvg: Double? { RHRDailyStats.baseline(dailyValues) }

    private var deviationPercent: Double? { RHRDailyStats.deviationPercent(dailyValues) }

    private var deltaText: String? {
        guard let pct = deviationPercent else { return nil }
        let sign = pct >= 0 ? "+" : ""
        return String(
            format: LocalePinnedStrings.localized("rhr.detail.delta.vsAvg", locale: locale),
            "\(sign)\(Int(pct))%"
        )
    }

    /// The reading the readout well reports: the scrubbed day, else the most recent.
    private var readoutPoint: (date: Date, value: Double)? {
        guard let selectedDate else { return data.last }
        return data.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } ?? data.last
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                AreaRule()

                HStack(spacing: 0) {
                    statCell(
                        index: 0,
                        label: "rhr.detail.label.daily",
                        value: latest.map { "\(Int($0))" } ?? "—",
                        unit: latest != nil ? "bpm" : nil,
                        // Reading Color Rule v6: this screen reports ONE metric, so its principal
                        // reading takes that metric's hue. RHR is recovery physiology (teal) —
                        // the same hue HRV wears, because they are the same area, not because
                        // they are the same measurement. Legal below 24pt: the stats band is a
                        // CARD plane.
                        valueColor: latest != nil ? ColorTokens.metricRecovery : ColorTokens.text1
                    )
                    AreaRule(axis: .vertical)
                    statCell(
                        index: 1,
                        label: "detail.label.sevenDayAvg",
                        value: sevenDayAvg.map { "\(Int($0))" } ?? "—",
                        unit: sevenDayAvg != nil ? "bpm" : nil
                    )
                    AreaRule(axis: .vertical)
                    statCell(
                        index: 2,
                        label: "rhr.detail.label.delta",
                        value: deltaText ?? "—",
                        unit: nil
                    )
                }
                .heroPlane()

                AreaRule()

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    RHRDetailChart(data: data, selectedDate: $selectedDate, windowDays: windowDays)
                    if let readoutPoint {
                        ChartReadoutWell(
                            dayStamp: dayStamp(for: readoutPoint.date),
                            value: "\(Int(readoutPoint.value.rounded())) bpm",
                            delta: deltaStamp(for: readoutPoint.value)
                        )
                    }
                    // Working voice: a sentence explaining a missing number. The annotation
                    // voice never speaks sentences.
                    if let availabilityNote {
                        Text(availabilityNote)
                            .font(.Tokens.smallLabel)
                            .foregroundStyle(ColorTokens.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.md)
                .simultaneousGesture(windowPinch)

                if !conditionRows.isEmpty {
                    AreaRule()
                    ReasonTreeSection(headKey: "rhr.detail.section.condition", rows: conditionRows)
                }

                AreaRule()

                DetailDisclosureList(
                    eyebrowKey: "rhr.detail.section.about",
                    items: [
                        DetailDisclosureItem(
                            titleKey: "rhr.detail.about.measures.title",
                            bodyKey: "rhr.detail.explanation"
                        ),
                        DetailDisclosureItem(
                            titleKey: "rhr.detail.about.direction.title",
                            bodyKey: "rhr.detail.about.direction.body"
                        ),
                        DetailDisclosureItem(
                            titleKey: "rhr.detail.about.window.title",
                            bodyKey: "rhr.detail.about.window.body"
                        ),
                        DetailDisclosureItem(
                            titleKey: "rhr.detail.about.baseline.title",
                            bodyKey: "rhr.detail.about.baseline.body"
                        )
                    ]
                )
            }
        }
        .background(ColorTokens.background)
        // v6.3 "The Area Tint": resting heart rate is recovery physiology, so this screen stands
        // in the RECOVERY area — the same area its sibling HRV screen declares. Declared on the
        // view rather than its fetching wrapper, so the hue is right whichever tab pushes it.
        .metricArea(.recovery)
        .navigationTitle(Text("recovery.label.restingHR"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let windowStamp {
                AnnotationLabel(windowStamp, size: .small)
                    .annotationReveal()
                    .padding(.bottom, Spacing.baselinePair)
            }
            Text("rhr.detail.header.title")
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text1)
                .padding(.bottom, Spacing.xs)
            Text(String(
                format: LocalePinnedStrings.localized("rhr.detail.header.subtitleFormat", locale: locale),
                windowDays
            ))
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    /// First calendar day inside the visible plot window (mirrors the chart's domain).
    private var windowStart: Date {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))!
        return calendar.date(byAdding: .day, value: -windowDays, to: end)!
    }

    /// Two-finger pinch retunes the plot window: fingers apart zoom IN (fewer days, wider
    /// marks), together zoom OUT toward 90 days. Same bounds as the HRV screen.
    private var windowPinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = pinchBaseWindow ?? windowDays
                pinchBaseWindow = base
                guard value.magnification > 0 else { return }
                let scaled = Double(base) / value.magnification
                windowDays = min(90, max(7, Int(scaled.rounded())))
            }
            .onEnded { _ in pinchBaseWindow = nil }
    }

    private var windowStamp: String? {
        let visible = data.filter { $0.date >= windowStart }
        guard let first = visible.first?.date, let last = visible.last?.date else { return nil }
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day().locale(locale)
        return "\(visible.count)D · \(first.formatted(format)) – \(last.formatted(format))"
    }

    /// Says WHY the screen has no numbers, instead of showing a bare "—". There is no
    /// "no morning samples" case here: RHR has no window filter, so a sample that exists
    /// always lands on a day.
    private var availabilityNote: String? {
        switch availability {
        case .noSamples:
            return nil   // the chart's own empty message already covers this
        case .building(let days):
            return String(
                format: LocalePinnedStrings.localized("rhr.detail.note.building", locale: locale),
                days,
                RHRDailyStats.minimumBaselineDays
            )
        case .ready:
            return nil
        }
    }

    // MARK: - Reason tree

    private var conditionRows: [String] {
        var rows: [String] = []
        if let latest {
            rows.append("LATEST: \(Int(latest.rounded())) bpm")
        }
        if let sevenDayAvg {
            rows.append("BASELINE_7D: \(Int(sevenDayAvg.rounded())) bpm")
        }
        if let pct = deviationPercent {
            rows.append(String(format: "DEVIATION: %@ %+.1f%%", deltaGlyph(for: pct), pct))
            // TRUE when the latest day sits at or BELOW the 7-day baseline — the inverse test to
            // HRV's, because for resting heart rate lower is the rested direction.
            rows.append("RHR_BASELINE: \(pct <= 0 ? "TRUE" : "FALSE")")
        }
        if let cv = coefficientOfVariation {
            rows.append(String(format: "CV_7D: %.1f%%", cv))
        }
        if let trend = trendToken {
            rows.append("TREND_7D: \(trend)")
        }
        return rows
    }

    private var baselineValues: [Double] {
        RHRDailyStats.baselineDays(dailyValues).map(\.value)
    }

    private var coefficientOfVariation: Double? {
        guard let sd = RHRDailyStats.standardDeviation(dailyValues),
              let mean = sevenDayAvg, mean > 0 else { return nil }
        return (sd / mean) * 100
    }

    /// Least-squares slope over the trailing baseline days, bucketed. `RecoveryScoreEngine`'s
    /// regression — the app's one implementation, shared with `FatigueIndexEngine` and the HRV
    /// screen. The token names the DIRECTION only; it does not say which direction is good.
    private var trendToken: String? {
        guard let slope = RecoveryScoreEngine.computeSlope(values: baselineValues) else { return nil }
        if slope > 0.5 { return "\u{25B2} RISING" }
        if slope < -0.5 { return "\u{25BC} FALLING" }
        return "= FLAT"
    }

    // MARK: - Formatting

    /// `▲` above +5%, `▼` below −5%, `=` between — DESIGN.md's delta glyph table. Ink, never a
    /// zone colour.
    private func deltaGlyph(for percent: Double) -> String {
        if percent > 5 { return "\u{25B2}" }
        if percent < -5 { return "\u{25BC}" }
        return "="
    }

    /// "now" is an English word, not a machine key, so it resolves through `LocalePinnedStrings`
    /// against the app's pinned locale (the `HRVDetailView` idiom — this well composes a
    /// `String`, not a `Text`). Authored lowercase: `AnnotationLabel` owns the uppercase
    /// transform and drops it for zh-Hans.
    private func dayStamp(for date: Date) -> String {
        if let last = data.last?.date, Calendar.current.isDate(date, inSameDayAs: last) {
            return LocalePinnedStrings.localized("detail.readout.now", locale: locale)
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.twoDigits).day().locale(locale))
    }

    private func deltaStamp(for value: Double) -> String? {
        guard let baseline = sevenDayAvg, baseline > 0 else { return nil }
        let pct = ((value - baseline) / baseline) * 100
        return String(
            format: LocalePinnedStrings.localized("rhr.detail.readout.vsBase", locale: locale),
            deltaGlyph(for: pct),
            pct
        )
    }

    /// One stat cell: a machine key, a reading, its unit. Key and unit are marginalia; the
    /// reading is working voice with tabular digits. The key is a `LocalizedStringKey` fed to
    /// `AnnotationLabel(key:)`, never a call-site `String(localized:)` — the literal path reads
    /// the PROCESS locale and would keep the launch language through an in-app switch.
    private func statCell(
        index: Int,
        label: LocalizedStringKey,
        value: String,
        unit: String?,
        valueColor: Color = ColorTokens.text1
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            AnnotationLabel(key: label, size: .small)
                .annotationReveal(index: index)
            HStack(alignment: .lastTextBaseline, spacing: Spacing.baselinePair) {
                Text(value)
                    .font(.Tokens.label)
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                if let unit {
                    AnnotationLabel(unit, size: .small, color: ColorTokens.text2)
                        .annotationReveal(index: index)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Chart

/// The zoomed resting-heart-rate plot. Structurally `HRVDetailChart`: explicit x-domain over the
/// trailing window, a dashed baseline rule with ±1 SD hairline bounds, an accent scrub rule and
/// an open-circle crosshair in the series hue.
///
/// The band is drawn as two hairline BOUNDS, never a filled area: an `AreaMark` in a metric hue
/// is a hue dressing a surface, which DESIGN.md forbids outright.
struct RHRDetailChart: View {
    @Environment(\.locale) private var locale
    let data: [(date: Date, value: Double)]
    @Binding var selectedDate: Date?
    var windowDays: Int = 28

    private var xDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))!
        let start = calendar.date(byAdding: .day, value: -windowDays, to: end)!
        return start...end
    }

    /// The readings inside the visible window. Baseline math stays on the FULL series' trailing
    /// days, so zooming the plot never moves the baseline.
    private var visibleData: [(date: Date, value: Double)] {
        data.filter { $0.date >= xDomain.lowerBound }
    }

    private var dailyValues: [RHRDailyStats.DailyValue] {
        data.map { RHRDailyStats.DailyValue(date: $0.date, value: $0.value) }
    }

    private var baseline: Double? { RHRDailyStats.baseline(dailyValues) }
    private var standardDeviation: Double? { RHRDailyStats.standardDeviation(dailyValues) }

    private var selectedValue: Double? {
        guard let selectedDate else { return nil }
        return data.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }?.value
    }

    var body: some View {
        if visibleData.isEmpty {
            Text("rhr.chart.empty.message")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Spacing.md)
        } else {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // The baseline key, above the plot (v6.1). Resolved through
                // `LocalePinnedStrings` rather than `AnnotationLabel(key:)`: it carries format
                // arguments, and a bare `String(localized:)` reads the PROCESS locale.
                if let baselineKey {
                    AnnotationLabel(baselineKey, size: .small)
                        .annotationReveal()
                }

                Chart {
                    ForEach(visibleData.indices, id: \.self) { i in
                        LineMark(
                            x: .value("Date", visibleData[i].date),
                            y: .value("RHR", visibleData[i].value)
                        )
                        .foregroundStyle(ColorTokens.metricRecovery)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .symbol(Circle())
                        .symbolSize(20)
                    }

                    if let baseline {
                        RuleMark(y: .value("Baseline", baseline))
                            .foregroundStyle(ColorTokens.text3)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))

                        if let standardDeviation, standardDeviation > 0 {
                            RuleMark(y: .value("Upper", baseline + standardDeviation))
                                .foregroundStyle(ColorTokens.text3)
                                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                            RuleMark(y: .value("Lower", baseline - standardDeviation))
                                .foregroundStyle(ColorTokens.text3)
                                .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 4]))
                        }
                    }

                    // Selection: the accent rule carries the live state (DESIGN.md), the open
                    // circle identifies the series datum and so wears the series hue.
                    if let selectedDate {
                        RuleMark(x: .value("Selected", selectedDate))
                            .foregroundStyle(ColorTokens.accent)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                    if let selectedDate, let selectedValue {
                        PointMark(
                            x: .value("Date", selectedDate),
                            y: .value("RHR", selectedValue)
                        )
                        .symbol {
                            Circle()
                                .stroke(ColorTokens.metricRecovery, lineWidth: 1.5)
                                .background(Circle().fill(ColorTokens.surfaceEl))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .chartXScale(domain: xDomain)
                .frame(height: 224)
                .chartOverlay { proxy in
                    ChartTooltipGesture(
                        proxy: proxy,
                        data: visibleData,
                        selectedDate: $selectedDate,
                        clearsOnEnd: false,
                        // 224pt of plot inside a long ScrollView: a zero-distance drag would own
                        // the touch from touch-down and stop a third of the screen scrolling.
                        yieldsToScroll: true
                    )
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: ChartAxisTicks.dayStride(spanningDays: windowDays))) { value in
                        AxisGridLine().foregroundStyle(ColorTokens.chartGrid)
                        AxisTick().foregroundStyle(ColorTokens.divider)
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
                            if let bpm = value.as(Double.self) {
                                AnnotationLabel(String(format: "%.0f", bpm), size: .small)
                            }
                        }
                    }
                }
                .chartYAxisLabel(position: .leading, alignment: .center) {
                    AnnotationLabel("bpm", size: .small)
                }
            }
            .id(locale)
            .entranceReveal()
        }
    }

    /// `7d avg: 52 bpm · ±1SD 49–55`, or the plain baseline key when the spread is undefined.
    private var baselineKey: String? {
        guard let baseline else { return nil }
        guard let standardDeviation, standardDeviation > 0 else {
            return String(
                format: LocalePinnedStrings.localized("rhr.chart.annotation", locale: locale),
                Int(baseline.rounded())
            )
        }
        return String(
            format: LocalePinnedStrings.localized("rhr.chart.annotation.band", locale: locale),
            Int(baseline.rounded()),
            Int((baseline - standardDeviation).rounded()),
            Int((baseline + standardDeviation).rounded())
        )
    }
}
