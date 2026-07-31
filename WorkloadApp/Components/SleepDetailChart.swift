import SwiftUI
import Charts

/// The **zoomed** 28-day sleep chart — the analytical surface behind the glance card.
///
/// `SleepTrendChart` (the glance) answers "is this normal?" with one rule and one key. This one
/// answers "why, and which night?": it adds the 6 h deficit floor, a three-cell plot key, a
/// persistent day scrub, and 224pt of height to read it in. It is a separate component rather
/// than a `variant:` flag on the glance because a branch inside the frozen path is exactly what
/// "the glance charts stay exactly as they are" forbids.
///
/// The bars stay a single indigo. Colour-coding each bar by its band is the obvious way to
/// "restore the three-swatch legend" and it is wrong: v6's thesis is one hue per metric, and
/// band-coloured bars would make sleep speak indigo on Recovery and traffic-light here — the same
/// inconsistency Wave 2 fixed for axis case. The bands are carried by rules and a key.
struct SleepDetailChart: View {
    @Environment(\.locale) private var locale
    let recoverySnapshots: [RecoverySnapshot]
    @Binding var selectedDate: Date?

    private var sleepData: [(date: Date, value: Double)] {
        recoverySnapshots.compactMap { snapshot in
            guard let minutes = snapshot.sleepDurationMinutes else { return nil }
            return (date: snapshot.date, value: minutes / 60.0)
        }
    }

    var body: some View {
        if sleepData.isEmpty {
            Text("sleep.chart.empty.message")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Spacing.md)
        } else {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Keys live ABOVE the plot, never as an in-plot `.annotation` on a rule mark
                // (v6.1 decision log: pinned to the rule they landed on the bars).
                ChartPlotKey(cells: keyCells)
                AnnotationLabel(
                    LocalePinnedStrings.localized("sleep.chart.annotation", locale: locale),
                    size: .small
                )
                .annotationReveal(index: 3)

                Chart {
                    ForEach(sleepData.indices, id: \.self) { i in
                        BarMark(
                            x: .value("Date", sleepData[i].date, unit: .day),
                            y: .value("Hours", sleepData[i].value)
                        )
                        .foregroundStyle(ColorTokens.metricSleep)
                    }

                    // The deficit floor. Finer dash than the target rule so it reads as the
                    // subordinate of the two, and zone-coloured because it names a state the key
                    // also spells out in words (never colour alone).
                    RuleMark(y: .value("Floor", RecoveryScoreEngine.sleepDeficitFloorHours))
                        .foregroundStyle(ColorTokens.zoneDanger)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))

                    // The 7.5 h target, in `text3` — the SAME colour the glance chart draws it
                    // in. One target, one colour, both screens.
                    RuleMark(y: .value("Target", RecoveryScoreEngine.sleepTargetHours))
                        .foregroundStyle(ColorTokens.text3)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))

                    // The scrub crosshair is a live-state mark, which is accent's exclusive
                    // territory (DESIGN.md:185) — not the sleep hue. Drawn only when a selection
                    // is actually live; the default state marks nothing and the well reads NOW.
                    if let selectedDate {
                        RuleMark(x: .value("Selected", selectedDate, unit: .day))
                            .foregroundStyle(ColorTokens.accent)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                }
                .frame(height: 224)
                .chartOverlay { proxy in
                    ChartTooltipGesture(
                        proxy: proxy,
                        data: sleepData,
                        selectedDate: $selectedDate,
                        clearsOnEnd: false,
                        // 224pt of plot inside a long ScrollView: a zero-distance drag would own
                        // the touch from touch-down and stop a third of the screen scrolling.
                        yieldsToScroll: true
                    )
                }
                // Axis labels host `AnnotationLabel` so the uppercase / tracking / zh-Hans guard
                // comes from the primitive rather than the call site — same reason as the glance.
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
                            if let hours = value.as(Double.self) {
                                AnnotationLabel(String(format: "%.0f", hours), size: .small)
                            }
                        }
                    }
                }
                .chartYAxisLabel(position: .leading, alignment: .center) {
                    // `hours` is a word, not a machine unit like `ms` — it takes the
                    // pinned-locale key path so zh-Hans reads 小时, not English.
                    AnnotationLabel(key: "chart.axis.hours", size: .small)
                }
            }
            .id(locale)
            .entranceReveal()
        }
    }

    /// Three cells, two swatches. The middle cell names the 6–7.5 h range but keys no mark,
    /// because the plot draws no mark there — so it carries no swatch glyph.
    private var keyCells: [ChartKeyCell] {
        [
            ChartKeyCell(
                swatch: ColorTokens.zoneDanger,
                rangeKey: "sleep.chart.legend.poor",
                stateKey: "sleep.detail.legend.state.deficit"
            ),
            ChartKeyCell(
                swatch: nil,
                rangeKey: "sleep.chart.legend.good",
                stateKey: "sleep.detail.legend.state.marginal"
            ),
            ChartKeyCell(
                swatch: ColorTokens.text3,
                rangeKey: "sleep.chart.legend.excellent",
                stateKey: "sleep.detail.legend.state.sufficient"
            )
        ]
    }
}
