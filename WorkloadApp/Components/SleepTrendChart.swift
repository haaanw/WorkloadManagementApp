import SwiftUI
import Charts

/// 28-day sleep duration bar chart, color-coded by duration.
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
            VStack(alignment: .leading, spacing: 16) {
                Chart {
                    ForEach(sleepData.indices, id: \.self) { i in
                        BarMark(
                            x: .value("Date", sleepData[i].date, unit: .day),
                            y: .value("Hours", sleepData[i].hours)
                        )
                        .foregroundStyle(sleepColor(hours: sleepData[i].hours))
                    }

                    RuleMark(y: .value("Target", 7))
                        .foregroundStyle(ColorTokens.text3)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("sleep.chart.annotation")
                                .font(.Tokens.micro)
                                .foregroundStyle(ColorTokens.text3)
                        }
                }
                .frame(height: 160)
                .chartYAxisLabel("hours")
                .id(locale)
                .entranceReveal()

                HStack(spacing: 16) {
                    legendItem(color: ColorTokens.zoneOptimal, label: String(localized: "sleep.chart.legend.excellent", defaultValue: "7h+"))
                    legendItem(color: ColorTokens.zoneCaution, label: String(localized: "sleep.chart.legend.good", defaultValue: "6–7h"))
                    legendItem(color: ColorTokens.zoneDanger,  label: String(localized: "sleep.chart.legend.poor", defaultValue: "<6h"))
                }
            }
        }
    }

    private func sleepColor(hours: Double) -> Color {
        switch hours {
        case 7...: ColorTokens.zoneOptimal
        case 6..<7: ColorTokens.zoneCaution
        default: ColorTokens.zoneDanger
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Rectangle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.Tokens.micro)
                .foregroundStyle(ColorTokens.text2)
        }
    }
}
