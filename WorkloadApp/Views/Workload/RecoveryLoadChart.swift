import SwiftUI
import Charts

/// 28-day recovery-load correlation chart (ANLYT-04).
/// BarMark for daily load + LineMark overlay for recovery score.
struct RecoveryLoadChart: View {
    let loadSnapshots: [WorkloadSnapshot]
    let recoverySnapshots: [RecoverySnapshot]
    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECOVERY vs LOAD \u{00B7} 28 DAYS")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)

            if loadSnapshots.count < 7 {
                Text("Log workouts for 7+ days to see recovery-load patterns.")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
            } else {
                chartContent
            }
        }
        .padding(.vertical, 16)
        .background(ColorTokens.background)
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
                .foregroundStyle(ColorTokens.zoneOptimal)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .frame(height: 180)
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
                    dateLabel: snapshot.snapshotDate.formatted(.dateTime.month(.abbreviated).day())
                )
            }
        }
        .padding(.horizontal, 16)
    }
}
