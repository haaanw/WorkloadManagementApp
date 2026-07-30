import SwiftUI
import Charts

/// 28-day sleep duration bar chart.
///
/// v6 "Field Notes" chart grammar: **sleep owns indigo** (`ColorTokens.metricSleep`), so the
/// series is drawn in its metric hue rather than colour-coded by duration band. That is the
/// point of the hue system — "each metric owns a hue, legends become unnecessary" — and it is
/// why the old three-swatch duration legend is gone: with one hue in the plot a colour key
/// describes marks that no longer exist. The sufficiency threshold survives where it always
/// carried the most weight, as the dashed 7 h target rule and its annotation callout.
///
/// Grid lines are `chartGrid` hairlines; axis labels and the target callout are in the
/// **annotation voice** at `annoSmall` (10pt). The raw `Font.Tokens.annoSmall` token appears
/// only inside `AxisValueLabel`, where Swift Charts cannot host an arbitrary `View`.
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
            Chart {
                ForEach(sleepData.indices, id: \.self) { i in
                    BarMark(
                        x: .value("Date", sleepData[i].date, unit: .day),
                        y: .value("Hours", sleepData[i].hours)
                    )
                    .foregroundStyle(ColorTokens.metricSleep)
                }

                RuleMark(y: .value("Target", 7))
                    .foregroundStyle(ColorTokens.text3)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        AnnotationLabel(
                            LocalePinnedStrings.localized("sleep.chart.annotation", locale: locale),
                            size: .small
                        )
                        .annotationReveal()
                    }
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
            .id(locale)
            .entranceReveal()
        }
    }
}
