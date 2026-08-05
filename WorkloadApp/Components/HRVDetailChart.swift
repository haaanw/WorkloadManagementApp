import SwiftUI
import Charts

/// The **zoomed** 28-day HRV chart — the analytical surface behind the glance card.
///
/// Beyond the glance it adds the ±1 SD band bounds, a persistent day scrub with an open-circle
/// crosshair, and 224pt of height. The band is drawn as two hairline **bounds**, never as a
/// filled area: an `AreaMark` in a metric hue is a hue dressing a surface, which DESIGN.md forbids
/// outright ("metric hues may NEVER be used as plane fills… decorative tints") and which Wave 2
/// already rejected once in the kit's TSB wash.
struct HRVDetailChart: View {
    @Environment(\.locale) private var locale
    let data: [(date: Date, value: Double)]
    @Binding var selectedDate: Date?
    /// Visible window, in days ending today. The pinch gesture on the detail screen
    /// drives it; 28 is the default reading.
    var windowDays: Int = 28

    /// Explicit x-domain (trailing `windowDays`, ending start-of-tomorrow). See
    /// `SleepDetailChart.xDomain` — same defect, same fix.
    private var xDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))!
        let start = calendar.date(byAdding: .day, value: -windowDays, to: end)!
        return start...end
    }

    /// The readings inside the visible window — what the marks and the scrub see.
    /// Baseline math below stays on the FULL series' trailing 7 days so zooming the
    /// plot never moves the baseline.
    private var visibleData: [(date: Date, value: Double)] {
        data.filter { $0.date >= xDomain.lowerBound }
    }

    private var recent: [Double] { data.suffix(7).map(\.value) }

    private var baseline: Double? {
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0, +) / Double(recent.count)
    }

    /// Population SD of the trailing 7 readings — the width of the band the athlete's own recent
    /// days occupy. Nil below two readings, where a spread is not a thing that exists yet.
    private var standardDeviation: Double? {
        guard recent.count >= 2, let mean = baseline else { return nil }
        let variance = recent.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(recent.count)
        return variance.squareRoot()
    }

    private var selectedValue: Double? {
        guard let selectedDate else { return nil }
        return data.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }?.value
    }

    var body: some View {
        if visibleData.isEmpty {
            Text("hrv.chart.empty.message")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Spacing.md)
        } else {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // The baseline key, above the plot (v6.1). It carries three numbers, so it is
                // resolved through `LocalePinnedStrings` rather than `AnnotationLabel(key:)`:
                // that initializer takes a `LocalizedStringKey` and cannot carry format
                // arguments, and a bare `String(localized:)` reads the PROCESS locale and would
                // keep the launch language through an in-app language switch. Locale-pinned
                // resolution is the requirement; `AnnotationLabel(key:)` is one way to meet it.
                if let baselineKey {
                    AnnotationLabel(baselineKey, size: .small)
                        .annotationReveal()
                }

                Chart {
                    ForEach(visibleData.indices, id: \.self) { i in
                        LineMark(
                            x: .value("Date", visibleData[i].date),
                            y: .value("HRV", visibleData[i].value)
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

                    // Selection: the accent rule carries the live-state (DESIGN.md:185), while the
                    // open circle identifies the series datum and so wears the series hue. Both
                    // laws served, neither bent.
                    if let selectedDate {
                        RuleMark(x: .value("Selected", selectedDate))
                            .foregroundStyle(ColorTokens.accent)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                    if let selectedDate, let selectedValue {
                        PointMark(
                            x: .value("Date", selectedDate),
                            y: .value("HRV", selectedValue)
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
                    AxisMarks { value in
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
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(ColorTokens.chartGrid)
                        AxisValueLabel {
                            if let milliseconds = value.as(Double.self) {
                                AnnotationLabel(String(format: "%.0f", milliseconds), size: .small)
                            }
                        }
                    }
                }
                .chartYAxisLabel(position: .leading, alignment: .center) {
                    AnnotationLabel("ms", size: .small)
                }
            }
            .id(locale)
            .entranceReveal()
        }
    }

    /// `7D AVG: 51 MS · ±1SD 46–56`, or the plain baseline key when the spread is undefined.
    private var baselineKey: String? {
        guard let baseline else { return nil }
        guard let standardDeviation, standardDeviation > 0 else {
            return String(
                format: LocalePinnedStrings.localized("hrv.chart.annotation", locale: locale),
                Int(baseline.rounded())
            )
        }
        return String(
            format: LocalePinnedStrings.localized("hrv.chart.annotation.band", locale: locale),
            Int(baseline.rounded()),
            Int((baseline - standardDeviation).rounded()),
            Int((baseline + standardDeviation).rounded())
        )
    }
}
