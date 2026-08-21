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

    /// The 28-day window the card claims, pinned explicitly (v1.7.2 / audit M9).
    ///
    /// Without it Swift Charts sizes the axis to whatever data happens to exist, so a week with
    /// three snapshots drew three bars across the full plot — the same defect the sleep and HRV
    /// charts were fixed for in v1.7.1. A chart headed "28 days" must span 28 days whether or
    /// not they are all populated.
    private var xDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))!
        let start = calendar.date(byAdding: .day, value: -28, to: end)!
        return start...end
    }

    /// Both series' days, so the scrub can reach a day that has a recovery score and no load —
    /// a rest day, which is exactly the day an athlete looks at this chart to understand
    /// (v1.7.2 / audit M9). Scrubbing used to snap only to load days, so rest days were
    /// unreachable.
    private var scrubDays: [(date: Date, value: Double)] {
        let calendar = Calendar.current
        var byDay: [Date: Double] = [:]
        for snapshot in recoverySnapshots {
            byDay[calendar.startOfDay(for: snapshot.date)] = 0
        }
        for snapshot in loadSnapshots {
            byDay[calendar.startOfDay(for: snapshot.snapshotDate)] = snapshot.acuteLoad
        }
        return byDay
            .map { (date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private var chartContent: some View {
        let maxLoad = loadSnapshots.map(\.acuteLoad).max() ?? 100
        // A week with no training has maxLoad 0, and 0/100 collapsed the whole recovery series
        // onto the baseline — the chart claimed a recovery score of zero on exactly the days it
        // was most likely to be high (v1.7.2 / audit M9). Fall back to the unscaled 0–100 range.
        let scaleFactor = maxLoad > 0 ? maxLoad / 100.0 : 1.0

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
                // A line through one point draws nothing. A single recovery reading in the
                // window rendered as an empty plot rather than as one score (v1.7.2 / audit M9).
                .symbol(.circle)
                .symbolSize(18)
            }
        }
        .frame(height: 184)
        .chartXScale(domain: xDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: ChartAxisTicks.dayStride(spanningDays: 28))) { value in
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
                data: scrubDays,
                selectedDate: $selectedDate
            )
        }
        .overlay(alignment: .top) {
            if let selectedDate {
                let calendar = Calendar.current
                let load = loadSnapshots.first { calendar.isDate($0.snapshotDate, inSameDayAs: selectedDate) }
                let recovery = recoverySnapshots.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
                // A day with only a recovery score is still a day worth reading — see
                // `scrubDays` (audit M9).
                if load != nil || recovery != nil {
                    TooltipBubble(
                        value: [
                            load.map { "Load: \(String(format: "%.0f", $0.acuteLoad))" },
                            recovery.map { "Recovery: \(Int($0.recoveryScore))" }
                        ].compactMap { $0 }.joined(separator: " | "),
                        dateLabel: selectedDate.formatted(.dateTime.month(.abbreviated).day().locale(locale))
                    )
                }
            }
        }
    }
}
