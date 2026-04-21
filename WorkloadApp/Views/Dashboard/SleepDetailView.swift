import SwiftUI

struct SleepDetailView: View {
    let snapshots: [RecoverySnapshot]

    private var lastNight: Double? {
        snapshots.last?.sleepDurationMinutes
    }
    private var sevenDayAvgMinutes: Double? {
        let recent = snapshots.suffix(7).compactMap(\.sleepDurationMinutes)
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0, +) / Double(recent.count)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("SLEEP TREND")
                        .font(.Tokens.pageTitle)
                        .foregroundStyle(ColorTokens.text1)
                    Text("28-day sleep duration")
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
                    statCell(label: "LAST NIGHT", value: lastNight.map { sleepString($0) } ?? "—")
                    Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                    statCell(label: "7-DAY AVG", value: sevenDayAvgMinutes.map { sleepString($0) } ?? "—")
                }
                .background(ColorTokens.surface)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Chart
                SleepTrendChart(recoverySnapshots: snapshots)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Explanation
                VStack(alignment: .leading, spacing: 8) {
                    Text("ABOUT SLEEP SCORING")
                        .font(.Tokens.micro)
                        .tracking(1.2)
                        .foregroundStyle(ColorTokens.text3)
                    Text("Sleep below 6 hours significantly reduces recovery score. The 7-hour target line is your minimum threshold for a green readiness score contribution.")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .background(ColorTokens.background)
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sleepString(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
            Text(value)
                .font(.Tokens.label)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}
