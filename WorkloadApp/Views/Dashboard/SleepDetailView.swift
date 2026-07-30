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
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("sleep.detail.header.title")
                        .font(.Tokens.pageTitle)
                        .foregroundStyle(ColorTokens.text1)
                    Text("sleep.detail.header.subtitle")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.md)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Stats row
                HStack(spacing: 0) {
                    statCell(
                        index: 0,
                        label: String(localized: "sleep.detail.label.lastNight", defaultValue: "LAST NIGHT"),
                        value: lastNight.map { sleepString($0) } ?? "—",
                        // Reading Color Rule v6: this screen reports sleep, so its principal
                        // reading takes the sleep hue (indigo). The 7-day baseline stays ink —
                        // one colored reading per screen. Card plane, 6.03:1.
                        valueColor: lastNight != nil ? ColorTokens.metricSleep : ColorTokens.text1
                    )
                    Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                    statCell(
                        index: 1,
                        label: String(localized: "detail.label.sevenDayAvg", defaultValue: "7-DAY AVG"),
                        value: sevenDayAvgMinutes.map { sleepString($0) } ?? "—"
                    )
                }
                // v2: the lifted stats band sits on the elevated plane (widened ladder), bounded
                // top/bottom by the full-width section hairlines.
                .background(ColorTokens.surfaceEl)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Chart
                SleepTrendChart(recoverySnapshots: snapshots)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.md)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Explanation. The eyebrow is a section head the app SAYS — working voice.
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("sleep.detail.section.about")
                        .font(.Tokens.micro)
                        .tracking(0.9)
                        .foregroundStyle(ColorTokens.text3)
                    Text("sleep.detail.explanation")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)
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

    /// One stat cell: a machine key in the annotation voice above a working-voice reading.
    private func statCell(
        index: Int,
        label: String,
        value: String,
        valueColor: Color = ColorTokens.text1
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            AnnotationLabel(label, size: .small)
                .annotationReveal(index: index)
            Text(value)
                .font(.Tokens.label)
                .monospacedDigit()
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
    }
}
