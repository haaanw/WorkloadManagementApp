import SwiftUI

struct HRVDetailView: View {
    let data: [(date: Date, value: Double)]

    private var latest: Double? { data.last?.value }
    private var sevenDayAvg: Double? {
        let recent = data.suffix(7)
        guard !recent.isEmpty else { return nil }
        return recent.map(\.value).reduce(0, +) / Double(recent.count)
    }
    private var deltaText: String? {
        guard let v = latest, let b = sevenDayAvg, b > 0 else { return nil }
        let pct = ((v - b) / b) * 100
        let sign = pct >= 0 ? "+" : ""
        return "\(sign)\(Int(pct))% vs 7-day avg"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("HRV TREND")
                        .font(.Tokens.pageTitle)
                        .foregroundStyle(ColorTokens.text1)
                    Text("28-day heart rate variability")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 32)
                .padding(.bottom, 24)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Stats row
                HStack(spacing: 0) {
                    statCell(
                        label: "LATEST",
                        value: latest.map { "\(Int($0))" } ?? "—",
                        unit: latest != nil ? "ms" : nil
                    )
                    Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                    statCell(
                        label: "7-DAY AVG",
                        value: sevenDayAvg.map { "\(Int($0))" } ?? "—",
                        unit: sevenDayAvg != nil ? "ms" : nil
                    )
                    Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                    statCell(
                        label: "DELTA",
                        value: deltaText ?? "—",
                        unit: nil
                    )
                }
                .background(ColorTokens.surface)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Chart
                HRVTrendChart(data: data)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Explanation
                VStack(alignment: .leading, spacing: 8) {
                    Text("ABOUT HRV")
                        .font(.Tokens.micro)
                        .tracking(1.2)
                        .foregroundStyle(ColorTokens.text3)
                    Text("Heart rate variability (SDNN) measures the variation between beats. Higher values indicate better autonomic recovery. The dashed line shows your 7-day rolling average.")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .background(ColorTokens.background)
        .navigationTitle("HRV")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statCell(label: String, value: String, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.Tokens.label)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.text1)
                if let unit {
                    Text(unit)
                        .font(.Tokens.micro)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}
