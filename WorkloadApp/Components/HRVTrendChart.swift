import SwiftUI
import Charts

/// 28-day HRV trend line chart with 7-day baseline rule mark.
struct HRVTrendChart: View {
    let data: [(date: Date, value: Double)]

    private var baseline: Double? {
        let recent = data.suffix(7)
        guard !recent.isEmpty else { return nil }
        return recent.map(\.value).reduce(0, +) / Double(recent.count)
    }

    var body: some View {
        if data.isEmpty {
            Text("No HRV data available. Connect a wearable device through Apple Health.")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 24)
        } else {
            Chart {
                ForEach(data.indices, id: \.self) { i in
                    LineMark(
                        x: .value("Date", data[i].date),
                        y: .value("HRV", data[i].value)
                    )
                    .foregroundStyle(ColorTokens.chartHRV)
                    .symbol(Circle())
                    .symbolSize(20)
                }

                if let baseline {
                    RuleMark(y: .value("Baseline", baseline))
                        .foregroundStyle(ColorTokens.text3)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("7d avg: \(Int(baseline)) ms")
                                .font(.Tokens.micro)
                                .foregroundStyle(ColorTokens.text3)
                        }
                }
            }
            .frame(height: 180)
            .chartYAxisLabel("ms")
        }
    }
}
