import SwiftUI
import Charts

/// 28-day recovery-load correlation chart (ANLYT-04).
/// BarMark for daily load + LineMark overlay for recovery score.
///
/// DESIGN.md v6 "Field Notes": the recovery series carries a METRIC IDENTITY, so it takes
/// `metricReadiness` (the readiness/recovery-score hue) instead of the identity-less warm-ink
/// `chartHRV` token. The daily-load BARS stay warm ink (`chartVolume`): v6 sanctions metric hues
/// as series LINES, state dots, "now" markers, and hero readings — a filled bar field is closer
/// to a plane than a line, and hue-as-surface is banned. Grid hairlines are `chartGrid`; axis
/// value labels move to the annotation voice (10pt Fragment Mono via `AnnotationLabel`).
struct RecoveryLoadChart: View {
    @Environment(\.locale) private var locale
    let loadSnapshots: [WorkloadSnapshot]
    let recoverySnapshots: [RecoverySnapshot]
    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if loadSnapshots.count < 7 {
                Text("workload.chart.insufficientData")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                chartContent
            }
        }
    }

    private var chartContent: some View {
        let maxLoad = loadSnapshots.map(\.acuteLoad).max() ?? 100
        let scaleFactor = maxLoad / 100.0

        return Chart {
            ForEach(loadSnapshots, id: \.id) { snapshot in
                BarMark(
                    x: .value("Date", snapshot.snapshotDate),
                    y: .value("Load", snapshot.acuteLoad)
                )
                .foregroundStyle(ColorTokens.chartVolume)
            }

            ForEach(recoverySnapshots, id: \.id) { snapshot in
                LineMark(
                    x: .value("Date", snapshot.date),
                    y: .value("Recovery", snapshot.recoveryScore * scaleFactor)
                )
                // v6: the recovery score is a METRIC — it wears its own hue
                // (`metricReadiness`), which is what makes a legend unnecessary here.
                .foregroundStyle(ColorTokens.metricReadiness)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .frame(height: 184)
        .chartXAxis {
            AxisMarks { value in
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
            AxisMarks { value in
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
                data: loadSnapshots.map { (date: $0.snapshotDate, value: $0.acuteLoad) },
                selectedDate: $selectedDate
            )
        }
        .overlay(alignment: .top) {
            if let selectedDate,
               let snapshot = loadSnapshots.first(where: { Calendar.current.isDate($0.snapshotDate, inSameDayAs: selectedDate) }) {
                let recovery = recoverySnapshots.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) })
                TooltipBubble(
                    value: "Load: \(String(format: "%.0f", snapshot.acuteLoad))" + (recovery.map { " | Recovery: \(Int($0.recoveryScore))" } ?? ""),
                    dateLabel: snapshot.snapshotDate.formatted(.dateTime.month(.abbreviated).day().locale(locale))
                )
            }
        }
    }
}
