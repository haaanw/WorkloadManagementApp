import SwiftUI

/// The zoomed HRV screen. Same grammar as `SleepDetailView`: context stamp → title → stats band →
/// scrubbable plot + persistent readout well → reason tree → expandable explanations.
struct HRVDetailView: View {
    let data: [(date: Date, value: Double)]

    @Environment(\.locale) private var locale
    @State private var selectedDate: Date?

    private var recent: [Double] { data.suffix(7).map(\.value) }
    private var latest: Double? { data.last?.value }

    private var sevenDayAvg: Double? {
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0, +) / Double(recent.count)
    }

    private var deviationPercent: Double? {
        guard let v = latest, let b = sevenDayAvg, b > 0 else { return nil }
        return ((v - b) / b) * 100
    }

    /// The DELTA cell's reading. Found alongside the Round-2 readout-well defects and fixed with
    /// them: "vs 7-day avg" is a phrase the app SAYS, and it was an English literal, so a zh-Hans
    /// user read it untranslated under a correctly-translated `变化` key.
    private var deltaText: String? {
        guard let pct = deviationPercent else { return nil }
        let sign = pct >= 0 ? "+" : ""
        return String(
            format: LocalePinnedStrings.localized("hrv.detail.delta.vsAvg", locale: locale),
            "\(sign)\(Int(pct))%"
        )
    }

    /// The reading the readout well is reporting: the scrubbed day, else the most recent.
    private var readoutPoint: (date: Date, value: Double)? {
        guard let selectedDate else { return data.last }
        return data.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } ?? data.last
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Stats row
                HStack(spacing: 0) {
                    statCell(
                        index: 0,
                        label: "hrv.detail.label.latest",
                        value: latest.map { "\(Int($0))" } ?? "—",
                        unit: latest != nil ? "ms" : nil,
                        // Reading Color Rule v6: this screen reports ONE metric, so its principal
                        // reading takes that metric's hue (HRV = teal). Legal below 24pt because
                        // the stats band is a CARD plane (5.19:1).
                        valueColor: latest != nil ? ColorTokens.metricRecovery : ColorTokens.text1
                    )
                    Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                    statCell(
                        index: 1,
                        label: "detail.label.sevenDayAvg",
                        value: sevenDayAvg.map { "\(Int($0))" } ?? "—",
                        unit: sevenDayAvg != nil ? "ms" : nil
                    )
                    Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                    statCell(
                        index: 2,
                        label: "hrv.detail.label.delta",
                        value: deltaText ?? "—",
                        unit: nil
                    )
                }
                // v2: the lifted stats band sits on the elevated plane (widened ladder), bounded
                // top/bottom by the full-width section hairlines.
                .background(ColorTokens.surfaceEl)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HRVDetailChart(data: data, selectedDate: $selectedDate)
                    if let readoutPoint {
                        ChartReadoutWell(
                            dayStamp: dayStamp(for: readoutPoint.date),
                            value: "\(Int(readoutPoint.value.rounded())) ms",
                            delta: deltaStamp(for: readoutPoint.value)
                        )
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.md)

                if !conditionRows.isEmpty {
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    ReasonTreeSection(headKey: "hrv.detail.section.condition", rows: conditionRows)
                }

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                DetailDisclosureList(
                    eyebrowKey: "hrv.detail.section.about",
                    items: [
                        DetailDisclosureItem(
                            titleKey: "hrv.detail.about.measures.title",
                            bodyKey: "hrv.detail.explanation"
                        ),
                        DetailDisclosureItem(
                            titleKey: "hrv.detail.about.deviation.title",
                            bodyKey: "hrv.detail.about.deviation.body"
                        ),
                        DetailDisclosureItem(
                            titleKey: "hrv.detail.about.baseline.title",
                            bodyKey: "hrv.detail.about.baseline.body"
                        )
                    ]
                )
            }
        }
        .background(ColorTokens.background)
        .navigationTitle(Text("recovery.label.hrv"))
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
            Text("hrv.detail.header.title")
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text1)
                .padding(.bottom, Spacing.xs)
            Text("hrv.detail.header.subtitle")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    private var windowStamp: String? {
        guard let first = data.first?.date, let last = data.last?.date else { return nil }
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day().locale(locale)
        return "\(data.count)D · \(first.formatted(format)) – \(last.formatted(format))"
    }

    // MARK: - Reason tree

    private var conditionRows: [String] {
        var rows: [String] = []
        if let latest {
            rows.append("LATEST: \(Int(latest.rounded())) ms")
        }
        if let sevenDayAvg {
            rows.append("BASELINE_7D: \(Int(sevenDayAvg.rounded())) ms")
        }
        if let pct = deviationPercent {
            rows.append(String(format: "DEVIATION: %@ %+.1f%%", deltaGlyph(for: pct), pct))
            // The machine key DESIGN.md prints as its own specimen — made real rather than
            // illustrative. TRUE when the latest reading sits at or above the 7-day baseline.
            rows.append("HRV_BASELINE: \(pct >= 0 ? "TRUE" : "FALSE")")
        }
        if let cv = coefficientOfVariation {
            // The stability read — what a rising-but-erratic HRV hides.
            rows.append(String(format: "CV_7D: %.1f%%", cv))
        }
        if let trend = trendToken {
            rows.append("TREND_7D: \(trend)")
        }
        return rows
    }

    private var coefficientOfVariation: Double? {
        guard recent.count >= 2, let mean = sevenDayAvg, mean > 0 else { return nil }
        let variance = recent.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(recent.count)
        return (variance.squareRoot() / mean) * 100
    }

    /// Least-squares slope over the trailing 7 readings, bucketed. The regression is
    /// `RecoveryScoreEngine.computeSlope(values:)` — the app's one implementation, already shared
    /// cross-file by `ShadowPredictor` and `FatigueIndexEngine`. Recomputing it locally would be a
    /// second copy of a published function, not a local detail.
    private var trendToken: String? {
        guard let slope = RecoveryScoreEngine.computeSlope(values: recent) else { return nil }
        if slope > 0.5 { return "\u{25B2} RISING" }
        if slope < -0.5 { return "\u{25BC} FALLING" }
        return "= FLAT"
    }

    // MARK: - Formatting

    /// `▲` above +5%, `▼` below −5%, `=` between — DESIGN.md's delta glyph table. Ink, never a
    /// zone colour: a reading below baseline is not a diagnosis, and colouring it red is exactly
    /// the pressure the nocebo guard exists to prevent.
    private func deltaGlyph(for percent: Double) -> String {
        if percent > 5 { return "\u{25B2}" }
        if percent < -5 { return "\u{25BC}" }
        return "="
    }

    /// "NOW" is an English word, not a machine key, so it is translated — resolved through
    /// `LocalePinnedStrings` against the app's pinned locale (the `HRVDetailChart` idiom in this
    /// same feature), because the well composes a `String` rather than a `Text`. Authored
    /// lowercase: `AnnotationLabel` owns the uppercase transform and drops it for zh-Hans.
    private func dayStamp(for date: Date) -> String {
        if let last = data.last?.date, Calendar.current.isDate(date, inSameDayAs: last) {
            return LocalePinnedStrings.localized("detail.readout.now", locale: locale)
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.twoDigits).day().locale(locale))
    }

    /// The glyph and the signed percentage are machine output; "vs base" is a phrase, so the
    /// whole stamp goes through a localized format rather than an English literal.
    private func deltaStamp(for value: Double) -> String? {
        guard let baseline = sevenDayAvg, baseline > 0 else { return nil }
        let pct = ((value - baseline) / baseline) * 100
        return String(
            format: LocalePinnedStrings.localized("hrv.detail.readout.vsBase", locale: locale),
            deltaGlyph(for: pct),
            pct
        )
    }

    /// One stat cell of the band: a machine key, a reading, and its unit. Key and unit are
    /// marginalia (`AnnotationLabel`); the reading is working voice with tabular digits.
    ///
    /// The key is a `LocalizedStringKey` fed to `AnnotationLabel(key:)`, NOT a call-site
    /// `String(localized:)`: the literal path resolves against the **process** locale and keeps
    /// the launch language until the app restarts, while the headers around it follow the app's
    /// pinned locale immediately — so an in-app language switch left this screen half English.
    /// (`unit` stays a literal: `ms` is a machine unit, never translated.)
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
