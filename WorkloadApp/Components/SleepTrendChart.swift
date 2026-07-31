import SwiftUI
import Charts

/// 28-day sleep duration bar chart.
///
/// v6 "Field Notes" chart grammar: **sleep owns indigo** (`ColorTokens.metricSleep`), so the
/// series is drawn in its metric hue rather than colour-coded by duration band. That is the
/// point of the hue system — "each metric owns a hue, legends become unnecessary" — and it is
/// why the old three-swatch duration legend is gone: with one hue in the plot a colour key
/// describes marks that no longer exist. The sufficiency threshold survives where it always
/// carried the most weight, as the dashed 7.5 h target rule and its annotation callout.
///
/// Grid lines are `chartGrid` hairlines; axis labels and the target key are in the
/// **annotation voice** at `annoSmall` (11pt), all of them via `AnnotationLabel` so the
/// uppercase/tracking/CJK law lives in one place. The target key is rendered **above the plot**
/// rather than as an in-plot mark annotation: pinned to the rule it sat on top of the bars and
/// neither could be read (v6.1, HAN 2026-07-30).
struct SleepTrendChart: View {
    @Environment(\.locale) private var locale
    let recoverySnapshots: [RecoverySnapshot]

    private var sleepData: [(date: Date, hours: Double)] {
        recoverySnapshots.compactMap { snapshot in
            guard let minutes = snapshot.sleepDurationMinutes else { return nil }
            return (date: snapshot.date, hours: minutes / 60.0)
        }
    }

    private var sevenDayAvg: Double? {
        let recent = sleepData.suffix(7)
        guard !recent.isEmpty else { return nil }
        return recent.map(\.hours).reduce(0, +) / Double(recent.count)
    }

    var body: some View {
        if sleepData.isEmpty {
            Text("sleep.chart.empty.message")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 24)
        } else {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // The target key sits ABOVE the plot, not pinned to the rule inside it. Anchored to
                // the rule at `.top`/`.trailing` it landed on the bars, and a label drawn over the
                // data it describes is the one place marginalia must never go. The dashed rule
                // still marks 7.5 h on the plot; the key states what the rule is.
                AnnotationLabel(
                    LocalePinnedStrings.localized("sleep.chart.annotation", locale: locale),
                    size: .small
                )
                .annotationReveal()

                Chart {
                    ForEach(sleepData.indices, id: \.self) { i in
                        BarMark(
                            x: .value("Date", sleepData[i].date, unit: .day),
                            y: .value("Hours", sleepData[i].hours)
                        )
                        .foregroundStyle(ColorTokens.metricSleep)
                    }

                    // 7.5 h, not 7 (HAN, 2026-07-31 — the target moved app-wide). Read from
                    // `RecoveryScoreEngine.sleepTargetHours` rather than typed here so the line
                    // the athlete sees and the knee the engine scores against cannot drift apart.
                    // This is the ONLY change to this frozen glance component: same colour
                    // (`text3`), same dash, same everything else — and the detail chart draws the
                    // same rule in the same `text3` so one target does not wear two colours.
                    RuleMark(y: .value("Target", RecoveryScoreEngine.sleepTargetHours))
                        .foregroundStyle(ColorTokens.text3)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                }
                .frame(height: 160)
                // Axis labels host `AnnotationLabel` for the same reason as `HRVTrendChart`: the font
                // token alone gives the mono face but not the uppercase, tracking, or zh-Hans guard,
                // which DESIGN.md rule 3 requires come from the modifier rather than the call site.
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
                    AnnotationLabel("hours", size: .small)
                }
            }
            .id(locale)
            .entranceReveal()
        }
    }
}
