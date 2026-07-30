import SwiftUI
import Charts

/// 28-day HRV trend line chart with 7-day baseline rule mark.
///
/// v6 "Field Notes" chart grammar: the series takes its **metric hue** — HRV is recovery
/// physiology, so `ColorTokens.metricRecovery` (teal) — drawn at 1.5pt; grid lines are
/// `chartGrid` hairlines; axis labels and the baseline key are in the **annotation voice**
/// at `annoSmall` (11pt). Marks are unrestricted by the contrast rule (3:1 graphical floor), and
/// a hue is a mark or a series here — never a fill or a wash.
///
/// Every annotation here — axis labels included — goes through `AnnotationLabel`, so the
/// uppercase/tracking/CJK law lives in exactly one place. The baseline key is rendered **above
/// the plot**, not as an in-plot mark annotation, because a label placed over the series it
/// describes is unreadable (v6.1, HAN 2026-07-30).
struct HRVTrendChart: View {
    @Environment(\.locale) private var locale
    let data: [(date: Date, value: Double)]

    private var baseline: Double? {
        let recent = data.suffix(7)
        guard !recent.isEmpty else { return nil }
        return recent.map(\.value).reduce(0, +) / Double(recent.count)
    }

    var body: some View {
        if data.isEmpty {
            Text("hrv.chart.empty.message")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 24)
        } else {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // The baseline key sits ABOVE the plot rather than pinned to the rule inside it.
                // An in-plot `.annotation(position: .top, alignment: .trailing)` lands exactly
                // where the series runs, so the label and the data drew over each other and both
                // lost legibility. Marginalia belongs in the margin — that is the whole metaphor
                // of the annotation voice, and a label competing with the data it describes is the
                // one place it must not be. The dashed rule still marks the value on the plot; the
                // key states what the rule is.
                if let baseline {
                    AnnotationLabel(
                        String(format: String(localized: "hrv.chart.annotation", defaultValue: "7d avg: %d ms"), Int(baseline)),
                        size: .small
                    )
                    .annotationReveal()
                }

                Chart {
                    ForEach(data.indices, id: \.self) { i in
                        LineMark(
                            x: .value("Date", data[i].date),
                            y: .value("HRV", data[i].value)
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
                    }
                }
                .frame(height: 184)
                // Axis labels host `AnnotationLabel` rather than taking `.font(.Tokens.annoSmall)` on a
                // bare `AxisValueLabel()`. The font token alone buys the Fragment Mono FACE but not the
                // uppercase transform, the tracking, or the zh-Hans guard — those live in the primitive
                // (DESIGN.md rule 3: applied by the token/modifier, never the call site). A bare
                // `AxisValueLabel()` therefore rendered "Jul 5" while the Load screen's charts rendered
                // "JUL 5", so the same axis spoke in two cases on adjacent tabs. Hosting the primitive
                // costs an explicit format string, which is also what keeps the label localized.
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
}
