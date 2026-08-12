import SwiftUI
import Charts

/// One night's breakdown — the page behind a scrubbed night on the sleep detail screen
/// (v1.7.1 round 2, HAN request). Same grammar as the other zoomed screens: context
/// stamp → title → stats band → plot → reason tree → about.
///
/// Input is a HealthKit-derived `SleepSessionMath.NightSummary` only — snapshot-fallback
/// nights carry no stage data and deliberately offer no route here (a breakdown of `—`
/// rows would read as a bug, not as missing data).
struct SleepNightDetailView: View {
    let night: SleepSessionMath.NightSummary
    let sevenDayAvgMinutes: Double?

    @Environment(\.locale) private var locale

    private var targetMinutes: Double { RecoveryScoreEngine.sleepTargetHours * 60 }

    private var efficiencyPercent: Int? {
        guard let inBed = night.inBedMinutes, inBed > 0 else { return nil }
        return Int(((night.tstMinutes / inBed) * 100).rounded())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Stats band: duration in the sleep hue (Reading Color Rule v6 — the
                // screen reports sleep, so its principal reading takes indigo; card
                // plane), the opportunity window and efficiency in ink.
                HStack(spacing: 0) {
                    statCell(
                        index: 0,
                        label: "sleep.night.label.duration",
                        value: sleepString(night.tstMinutes),
                        valueColor: ColorTokens.metricSleep
                    )
                    Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                    statCell(
                        index: 1,
                        label: "sleep.night.label.inBed",
                        value: night.inBedMinutes.map { sleepString($0) } ?? "—"
                    )
                    Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                    statCell(
                        index: 2,
                        label: "sleep.night.label.efficiency",
                        value: efficiencyPercent.map { "\($0)%" } ?? "—"
                    )
                }
                .background(ColorTokens.surfaceEl)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                if !night.segments.isEmpty {
                    timeline
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.md)
                }

                if !stageRows.isEmpty {
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    ReasonTreeSection(headKey: "sleep.night.section.stages", rows: stageRows)
                }

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                ReasonTreeSection(headKey: "sleep.night.section.facts", rows: factRows)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                DetailDisclosureList(
                    eyebrowKey: "sleep.detail.section.about",
                    items: [
                        DetailDisclosureItem(
                            titleKey: "sleep.night.about.title",
                            bodyKey: "sleep.night.about.body"
                        )
                    ]
                )
            }
        }
        .background(ColorTokens.background)
        .navigationTitle(Text("sleep.night.navTitle"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            AnnotationLabel(
                night.wakeDay.formatted(
                    .dateTime.weekday(.abbreviated).month(.abbreviated).day().locale(locale)
                ),
                size: .small
            )
            .annotationReveal()
            .padding(.bottom, Spacing.baselinePair)
            Text("sleep.night.header.title")
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text1)
                .padding(.bottom, Spacing.xs)
            // The session span in the working voice: this is the sentence-level answer
            // ("when did I actually sleep"), not marginalia.
            Text(sessionSpanText)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    private var sessionSpanText: String {
        let style = Date.FormatStyle.dateTime.hour().minute().locale(locale)
        return "\(night.sessionStart.formatted(style)) – \(night.sessionEnd.formatted(style))"
    }

    // MARK: - Timeline

    /// The hypnogram. One row per stage present, marks in the sleep hue's opacity ladder
    /// (deep darkest — depth reads as saturation), awake in neutral ink. No legend: the
    /// y-axis labels name every row directly, which is why the rows are category-scaled.
    private var timeline: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            AnnotationLabel(
                LocalePinnedStrings.localized("sleep.night.timeline.annotation", locale: locale),
                size: .small
            )
            .annotationReveal()

            Chart {
                ForEach(night.segments) { segment in
                    RectangleMark(
                        xStart: .value("Start", segment.interval.start),
                        xEnd: .value("End", segment.interval.end),
                        y: .value("Stage", stageLabel(segment.stage))
                    )
                    .foregroundStyle(stageColor(segment.stage))
                }
            }
            .chartYScale(domain: stageOrder)
            .chartXScale(domain: night.sessionStart...night.sessionEnd)
            .frame(height: CGFloat(stageOrder.count) * 40)
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(ColorTokens.chartGrid)
                    AxisTick().foregroundStyle(ColorTokens.divider)
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            AnnotationLabel(
                                date.formatted(.dateTime.hour().minute().locale(locale)),
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
                        if let label = value.as(String.self) {
                            AnnotationLabel(label, size: .small)
                        }
                    }
                }
            }
        }
        .id(locale)
        .entranceReveal()
    }

    /// Rows top → bottom: awake, REM, core, deep — the Health ordering the athlete
    /// already reads. Only stages the night actually contains get a row.
    private var stageOrder: [String] {
        let present = Set(night.segments.map(\.stage))
        return ([.awake, .rem, .core, .unspecified, .deep] as [SleepSessionMath.Stage])
            .filter { present.contains($0) }
            .map { stageLabel($0) }
    }

    private func stageLabel(_ stage: SleepSessionMath.Stage) -> String {
        let key: String.LocalizationValue
        switch stage {
        case .deep: key = "sleep.night.stage.deep"
        case .core: key = "sleep.night.stage.core"
        case .rem: key = "sleep.night.stage.rem"
        case .unspecified: key = "sleep.night.stage.unspecified"
        case .awake: key = "sleep.night.stage.awake"
        case .inBed: key = "sleep.night.stage.awake"
        }
        return LocalePinnedStrings.localized(key, locale: locale)
    }

    /// Depth as saturation on the ONE sleep hue — never a second hue. Awake is neutral
    /// ink: it is the absence of sleep, not a metric of its own.
    private func stageColor(_ stage: SleepSessionMath.Stage) -> Color {
        switch stage {
        case .deep: ColorTokens.metricSleep
        case .core, .unspecified: ColorTokens.metricSleep.opacity(0.55)
        case .rem: ColorTokens.metricSleep.opacity(0.3)
        case .awake, .inBed: ColorTokens.text3
        }
    }

    // MARK: - Reason trees

    /// Machine rows: stage minutes with their share of total sleep time.
    private var stageRows: [String] {
        var rows: [String] = []
        func row(_ key: String, _ minutes: Double?) {
            guard let minutes, night.tstMinutes > 0 else { return }
            let percent = Int(((minutes / night.tstMinutes) * 100).rounded())
            rows.append("\(key): \(sleepString(minutes)) · \(percent)%")
        }
        row("DEEP", night.deepMinutes)
        row("CORE", night.coreMinutes)
        row("REM", night.remMinutes)
        if let awake = night.awakeMinutes, let episodes = night.awakeEpisodes, awake > 0 {
            rows.append("AWAKE: \(sleepString(awake)) · ×\(episodes)")
        }
        return rows
    }

    private var factRows: [String] {
        let style = Date.FormatStyle.dateTime.hour().minute().locale(locale)
        var rows: [String] = [
            "BEDTIME: \(night.sessionStart.formatted(style))",
            "WAKE: \(night.sessionEnd.formatted(style))"
        ]
        let targetDelta = Int((night.tstMinutes - targetMinutes).rounded())
        rows.append("VS_TARGET: \(targetDelta >= 0 ? "+" : "")\(targetDelta)m")
        if let avg = sevenDayAvgMinutes {
            let delta = Int((night.tstMinutes - avg).rounded())
            rows.append("VS_AVG_7D: \(delta >= 0 ? "+" : "")\(delta)m")
        }
        if let source = night.dominantSourceID?.split(separator: ".").last {
            rows.append("SOURCE: \(source)")
        }
        return rows
    }

    // MARK: - Formatting

    private func sleepString(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        if h == 0 { return "\(m)m" }
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    private func statCell(
        index: Int,
        label: LocalizedStringKey,
        value: String,
        valueColor: Color = ColorTokens.text1
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            AnnotationLabel(key: label, size: .small)
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
