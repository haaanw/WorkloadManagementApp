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
                    Text("sleep.detail.header.title")
                        .font(.Tokens.pageTitle)
                        .foregroundStyle(ColorTokens.text1)
                    Text("sleep.detail.header.subtitle")
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
                    statCell(label: String(localized: "sleep.detail.label.lastNight", defaultValue: "LAST NIGHT"), value: lastNight.map { sleepString($0) } ?? "—")
                    Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                    statCell(label: String(localized: "detail.label.sevenDayAvg", defaultValue: "7-DAY AVG"), value: sevenDayAvgMinutes.map { sleepString($0) } ?? "—")
                }
                // v2: the lifted stats band sits on the elevated plane (widened ladder), bounded
                // top/bottom by the full-width section hairlines.
                .background(ColorTokens.surfaceEl)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Chart
                SleepTrendChart(recoverySnapshots: snapshots)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Explanation
                VStack(alignment: .leading, spacing: 8) {
                    Text("sleep.detail.section.about")
                        .font(.Tokens.micro)
                        .tracking(1.2)
                        .foregroundStyle(ColorTokens.text3)
                    Text("sleep.detail.explanation")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .background(ColorTokens.background)
        .navigationTitle(Text("recovery.label.sleep"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sleepString(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
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
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
    }
}
