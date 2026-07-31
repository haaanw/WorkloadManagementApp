import SwiftUI

/// The zoomed sleep screen. The glance card on Recovery answers "is this normal?"; this screen is
/// where the data dump is legal — DESIGN.md's progressive disclosure, "score → reasons → trends".
struct SleepDetailView: View {
    let snapshots: [RecoverySnapshot]

    @Environment(\.locale) private var locale
    @State private var selectedDate: Date?

    private var nights: [(date: Date, minutes: Double)] {
        snapshots.compactMap { snapshot in
            guard let minutes = snapshot.sleepDurationMinutes else { return nil }
            return (date: snapshot.date, minutes: minutes)
        }
    }

    private var lastNight: Double? { nights.last?.minutes }

    private var sevenDayAvgMinutes: Double? {
        let recent = nights.suffix(7).map(\.minutes)
        guard !recent.isEmpty else { return nil }
        return recent.reduce(0, +) / Double(recent.count)
    }

    /// The night the readout well is reporting: the scrubbed one, else the most recent.
    private var readoutNight: (date: Date, minutes: Double)? {
        guard let selectedDate else { return nights.last }
        return nights.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } ?? nights.last
    }

    private var targetMinutes: Double { RecoveryScoreEngine.sleepTargetHours * 60 }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                // Stats row
                HStack(spacing: 0) {
                    statCell(
                        index: 0,
                        label: "sleep.detail.label.lastNight",
                        value: lastNight.map { sleepString($0) } ?? "—",
                        // Reading Color Rule v6: this screen reports sleep, so its principal
                        // reading takes the sleep hue (indigo). Card plane, 6.03:1.
                        valueColor: lastNight != nil ? ColorTokens.metricSleep : ColorTokens.text1
                    )
                    Rectangle().fill(ColorTokens.divider).frame(width: 0.5)
                    statCell(
                        index: 1,
                        label: "detail.label.sevenDayAvg",
                        value: sevenDayAvgMinutes.map { sleepString($0) } ?? "—"
                    )
                }
                // v2: the lifted stats band sits on the elevated plane (widened ladder), bounded
                // top/bottom by the full-width section hairlines.
                .background(ColorTokens.surfaceEl)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    SleepDetailChart(recoverySnapshots: snapshots, selectedDate: $selectedDate)
                    if let readoutNight {
                        ChartReadoutWell(
                            dayStamp: dayStamp(for: readoutNight.date),
                            value: sleepString(readoutNight.minutes),
                            delta: deltaStamp(for: readoutNight.minutes)
                        )
                    }
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.md)

                if !conditionRows.isEmpty {
                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    ReasonTreeSection(headKey: "sleep.detail.section.condition", rows: conditionRows)
                }

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                DetailDisclosureList(
                    eyebrowKey: "sleep.detail.section.about",
                    items: [
                        DetailDisclosureItem(
                            titleKey: "sleep.detail.about.scoring.title",
                            bodyKey: "sleep.detail.explanation"
                        ),
                        DetailDisclosureItem(
                            titleKey: "sleep.detail.about.sixHour.title",
                            bodyKey: "sleep.detail.about.sixHour.body"
                        ),
                        DetailDisclosureItem(
                            titleKey: "sleep.detail.about.target.title",
                            bodyKey: "sleep.detail.about.target.body"
                        )
                    ]
                )
            }
        }
        .background(ColorTokens.background)
        .navigationTitle(Text("recovery.label.sleep"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    /// The context line DESIGN.md's Layout section calls for, and which v6 names as "the natural
    /// home of an annotation stamp". `28D` is a machine token in the same register as `ATL`/`ACWR`
    /// (already printed untranslated by the Load chart); the dates go through `.locale(locale)` so
    /// zh-Hans renders `7月3日 – 7月30日`, and `AnnotationLabel` suppresses case and tracking there.
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let windowStamp {
                AnnotationLabel(windowStamp, size: .small)
                    .annotationReveal()
                    .padding(.bottom, Spacing.baselinePair)
            }
            Text("sleep.detail.header.title")
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text1)
                .padding(.bottom, Spacing.xs)
            Text("sleep.detail.header.subtitle")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.md)
    }

    private var windowStamp: String? {
        guard let first = nights.first?.date, let last = nights.last?.date else { return nil }
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day().locale(locale)
        return "\(nights.count)D · \(first.formatted(format)) – \(last.formatted(format))"
    }

    // MARK: - Reason tree

    /// Rows are suppressed individually when their input is missing. A tree with `—` holes is
    /// worse than a shorter tree: the stem implies a derivation, and a derivation with gaps reads
    /// as a bug rather than as missing data.
    private var conditionRows: [String] {
        var rows: [String] = []
        // `LAST_NIGHT:` / `AVG_7D:`, not `LAST NIGHT:` / `7D AVG:` — the underscored form is a
        // true machine key in the register of the rows beneath it (`SLEEP_DEBT_7D`,
        // `NIGHTS_BELOW_6H`, `SCORE_CONTRIB`), which DESIGN.md sanctions untranslated. The spaced
        // English phrases were not machine keys; they were English, sitting untranslated under a
        // correctly-translated `昨晚`.
        if let lastNight {
            rows.append("LAST_NIGHT: \(sleepString(lastNight))")
        }
        if let sevenDayAvgMinutes {
            rows.append("AVG_7D: \(sleepString(sevenDayAvgMinutes))")
        }
        let window = nights.suffix(7)
        if !window.isEmpty {
            // Debt is measured against the same target the plot draws — one number, one meaning.
            let debtMinutes = window.reduce(0.0) { $0 + max(0, targetMinutes - $1.minutes) }
            rows.append(String(format: "SLEEP_DEBT_7D: %.1fh", debtMinutes / 60))
            let floorMinutes = RecoveryScoreEngine.sleepDeficitFloorHours * 60
            let short = window.filter { $0.minutes < floorMinutes }.count
            // Denominator is the number of nights WITH data, so a five-night week reads `1 / 5`
            // rather than silently claiming seven.
            rows.append("NIGHTS_BELOW_6H: \(short) / \(window.count)")
        }
        if let lastNight {
            // The engine's own curve, not a copy of it. Two copies of a scoring function drift.
            let contribution = RecoveryScoreEngine.sleepDurationToScore(lastNight)
            rows.append("SCORE_CONTRIB: \(Int(contribution.rounded())) / 100")
        }
        return rows
    }

    // MARK: - Formatting

    private func sleepString(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    /// `● NOW` for the most recent night (the filled state dot is the sanctioned "live" glyph),
    /// otherwise a weekday-and-date stamp.
    ///
    /// "NOW" is an English word, not a machine key, so it is translated — resolved through
    /// `LocalePinnedStrings` against the app's pinned locale (the `HRVDetailChart` idiom), since
    /// this is a `String` the well composes rather than a `Text` SwiftUI can resolve. The string
    /// is authored lowercase: `AnnotationLabel` owns the uppercase transform and suppresses it
    /// for zh-Hans.
    private func dayStamp(for date: Date) -> String {
        if let last = nights.last?.date, Calendar.current.isDate(date, inSameDayAs: last) {
            return LocalePinnedStrings.localized("detail.readout.now", locale: locale)
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.twoDigits).day().locale(locale))
    }

    /// Signed delta against the 7.5 h target. Ink, never a zone colour: the nocebo guard makes
    /// colouring a short night red an active harm, and the well is not a card plane anyway.
    ///
    /// "vs target" is a phrase, not a machine key — it is translated. This well is the screen's
    /// centrepiece; leaving `▼ -45m vs target` in English directly under a translated `昨晚` is
    /// exactly what DESIGN.md's machine-key sanction does NOT cover.
    private func deltaStamp(for minutes: Double) -> String {
        let delta = Int((minutes - targetMinutes).rounded())
        if delta == 0 {
            return LocalePinnedStrings.localized("sleep.detail.readout.onTarget", locale: locale)
        }
        let key: String.LocalizationValue = delta > 0
            ? "sleep.detail.readout.aboveTarget"
            : "sleep.detail.readout.belowTarget"
        let glyph = delta > 0 ? "\u{25B2}" : "\u{25BC}"
        return String(
            format: LocalePinnedStrings.localized(key, locale: locale),
            glyph,
            abs(delta)
        )
    }

    /// One stat cell: a machine key in the annotation voice above a working-voice reading.
    ///
    /// The key is a `LocalizedStringKey` fed to `AnnotationLabel(key:)`, NOT a call-site
    /// `String(localized:)`: the literal path resolves against the **process** locale and keeps
    /// the launch language until the app restarts, while the headers around it follow the app's
    /// pinned locale immediately — so an in-app language switch left this screen half English.
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
