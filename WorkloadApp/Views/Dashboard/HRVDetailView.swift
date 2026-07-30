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
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("hrv.detail.header.title")
                        .font(.Tokens.pageTitle)
                        .foregroundStyle(ColorTokens.text1)
                    Text("hrv.detail.header.subtitle")
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
                        label: String(localized: "hrv.detail.label.latest", defaultValue: "LATEST"),
                        value: latest.map { "\(Int($0))" } ?? "—",
                        unit: latest != nil ? "ms" : nil,
                        // Reading Color Rule v6: this screen reports ONE metric, so its
                        // principal reading takes that metric's hue (HRV = teal). The 7-day
                        // baseline and the delta stay in ink — one colored reading per screen.
                        // Legal below 24pt because the stats band is a CARD plane (5.19:1).
                        valueColor: latest != nil ? ColorTokens.metricRecovery : ColorTokens.text1
                    )
                    Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                    statCell(
                        index: 1,
                        label: String(localized: "detail.label.sevenDayAvg", defaultValue: "7-DAY AVG"),
                        value: sevenDayAvg.map { "\(Int($0))" } ?? "—",
                        unit: sevenDayAvg != nil ? "ms" : nil
                    )
                    Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                    statCell(
                        index: 2,
                        label: String(localized: "hrv.detail.label.delta", defaultValue: "DELTA"),
                        value: deltaText ?? "—",
                        unit: nil
                    )
                }
                // v2: the lifted stats band sits on the elevated plane (widened ladder), bounded
                // top/bottom by the full-width section hairlines.
                .background(ColorTokens.surfaceEl)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Chart
                HRVTrendChart(data: data)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.md)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Explanation. The eyebrow ("About HRV") is a section head the app SAYS, not a
                // machine key — it stays in the working voice (DESIGN.md v6: annotation never
                // takes a headline).
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("hrv.detail.section.about")
                        .font(.Tokens.micro)
                        .tracking(0.9)
                        .foregroundStyle(ColorTokens.text3)
                    Text("hrv.detail.explanation")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)
            }
        }
        .background(ColorTokens.background)
        .navigationTitle(Text("recovery.label.hrv"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// One stat cell of the band: a machine key, a reading, and its unit. Key and unit are
    /// marginalia (`AnnotationLabel`); the reading is working voice with tabular digits.
    private func statCell(
        index: Int,
        label: String,
        value: String,
        unit: String?,
        valueColor: Color = ColorTokens.text1
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            AnnotationLabel(label, size: .small)
                .annotationReveal(index: index)
            HStack(alignment: .lastTextBaseline, spacing: Spacing.baselinePair) {
                Text(value)
                    .font(.Tokens.label)
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                if let unit {
                    AnnotationLabel(unit, size: .small, color: ColorTokens.text2)
                        .annotationReveal(index: index)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
    }
}
