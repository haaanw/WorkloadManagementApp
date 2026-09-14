import SwiftUI

/// The pre-session **brief** — the screen between Today's one pill and the guided session
/// (v1.7.3 UAT round 3 · U25).
///
/// HAN's finding: Today opened with a fatigue caution ("body stress elevated — deload day /
/// active recovery recommended") sitting above everything, and there was no single place that
/// said *what the app sees, what it therefore suggests, and what the numbers become*. The banner
/// is gone; this screen is where that sentence lives, and it is reached by ONE action.
///
/// Three blocks, in the working voice, in the order an athlete actually asks them:
///  1. **What today looks like** — readings only. Readiness, fatigue, the three body signals
///     against their own baselines, and how close the next match is. Nothing here recommends
///     anything; it is the evidence the block below is built on. The former banner's one line
///     becomes the fatigue row's reading.
///  2. **So today** — the verdict and its one-line reason, then the equal-weight
///     Accept / Keep as planned pair (the same `KeyRow` grammar the card uses — SC1's nocebo
///     guard is that neither cell is dressed as the endorsed one).
///  3. **Your numbers** — per movement, the athlete's planned number and the suggestion beside
///     it; on a non-strength day, the session cap instead (duration + RPE ceiling).
///
/// ONE ink-filled pill on the screen: Start. Every other control is a plain cell or a text
/// button, so the CTA Law holds at one per screen.
///
/// DESIGN.md v6: corners via `CornerTokens`, no shadows, 8pt grid, light-only `ColorTokens`,
/// two-voice type (Instrument Sans speaks, `AnnotationLabel` annotates at ≤12pt). Today is the
/// READINESS area, and the brief is Today's screen, so it declares that area (v6.3).
struct PreSessionBriefView: View {

    /// The live verdict state. Held as the `@Observable` object rather than a snapshot so the
    /// blocks re-read themselves the instant a decision lands — there is no second state model.
    let viewModel: TodayVerdictViewModel
    let weightUnit: WeightUnit
    /// Fired after a decision so the host can refresh the readings that cite it.
    var onProposalChanged: () -> Void = {}

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    /// Presented via `.sheet(item:)` — an `isPresented` boolean racing an optional plan is what
    /// presented an empty sheet on the Today surface once already.
    @State private var startedPlan: ResolvedSessionPlan?

    private var display: TodayVerdictDisplay? { viewModel.display }
    private var readings: TodayBriefReadings? { viewModel.briefReadings }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Both slots LABELLED: an unlabelled trailing closure is sent to `trailing` by
                // Swift's backward matching, which is what moved seven sheets' Cancel buttons.
                InstrumentSheetHeader(
                    title: "brief.nav.title",
                    leading: {
                        SheetHeaderButton(title: "action.cancel") { dismiss() }
                    },
                    trailing: { EmptyView() }
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        todayLooksLikeBlock
                        soTodayBlock
                        yourNumbersBlock
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.md)
                }

                startBar
            }
            .background(ColorTokens.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .metricArea(.readiness)
        .sheet(item: $startedPlan, onDismiss: {
            onProposalChanged()
            dismiss()
        }) { plan in
            ActiveWorkoutSheet(resolvedPlan: plan)
                .environment(container)
        }
    }

    // MARK: - 1. What today looks like (readings only)

    private var todayLooksLikeBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            RuledSectionHeader(title: "brief.section.today")
            VStack(alignment: .leading, spacing: 0) {
                readingRow(
                    label: "brief.reading.readiness",
                    value: readinessValue,
                    note: readinessNote
                )
                RowSeparator()
                readingRow(
                    label: "brief.reading.fatigue",
                    value: fatigueValue,
                    note: fatigueNote
                )
                RowSeparator()
                readingRow(label: "brief.reading.hrv", value: hrvValue, note: hrvNote)
                RowSeparator()
                readingRow(label: "brief.reading.rhr", value: rhrValue, note: rhrNote)
                RowSeparator()
                readingRow(label: "brief.reading.sleep", value: sleepValue, note: sleepNote)
                if let matchNote {
                    RowSeparator()
                    readingRow(label: "brief.reading.match", value: matchNote, note: nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .cardStyle(horizontalPadding: 0, verticalPadding: 0)
        }
    }

    /// One reading: what it is (annotation), the number (working voice), and how it sits against
    /// the athlete's own baseline (annotation). Never a recommendation.
    private func readingRow(label: LocalizedStringKey, value: String, note: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            AnnotationLabel(key: label, color: ColorTokens.text2)
                .frame(width: 88, alignment: .leading)
            Text(verbatim: value)
                .font(.Tokens.body)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Spacing.xs)
            if let note {
                AnnotationLabel(note)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 2. So today (the verdict + the equal-weight decision)

    private var soTodayBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            RuledSectionHeader(title: "brief.section.soToday")
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(verbatim: verdictHeadline)
                    .font(.Tokens.bodyMedium)
                    .foregroundStyle(ColorTokens.text1)
                    .fixedSize(horizontal: false, vertical: true)

                if let reason = display?.reasonLine, !reason.isEmpty {
                    Text(verbatim: reason)
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("brief.reason")
                }

                if let note = display?.confidenceNote {
                    Text(verbatim: note)
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text3)
                }

                decisionRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .emphasisCardStyle(horizontalPadding: Spacing.sm, verticalPadding: Spacing.sm)
        }
    }

    /// Accept and Keep as planned are BOTH plain cells in one butted row — identical size, type,
    /// fill and press treatment. Neither is given the CTA role; the screen's one ink pill is Start,
    /// and it only appears once a decision exists.
    @ViewBuilder
    private var decisionRow: some View {
        if viewModel.decisionState != .pending {
            Text(verbatim: confirmedLine)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .accessibilityIdentifier("brief.confirmed")
        } else if hasNothingToDecide {
            // Nothing was changed, so there is nothing to accept or decline — one
            // friction-free acknowledge, exactly as the card does on a steady day.
            KeyRow([
                KeyRow.Key(title: "verdictCard.action.gotIt", accessibilityID: "brief.gotIt") {
                    viewModel.keepPlan()
                    onProposalChanged()
                }
            ])
        } else {
            KeyRow([
                KeyRow.Key(
                    title: acceptCellTitle,
                    accessibilityID: "brief.accept"
                ) {
                    viewModel.accept()
                    onProposalChanged()
                },
                KeyRow.Key(
                    title: "verdictCard.action.keep",
                    accessibilityID: "brief.keepPlan"
                ) {
                    viewModel.keepPlan()
                    onProposalChanged()
                }
            ])
        }
    }

    /// The card's own rule, restated once: a steady lift day and an unchanged cap day both have
    /// nothing to weigh up.
    private var hasNothingToDecide: Bool {
        guard let display else { return true }
        switch display.kind {
        case .asPlanned:  return true
        case .sessionCap: return !display.capModulatesPlan
        case .adjusted, .deferred: return false
        }
    }

    /// The accept cell's verb: on a cap day it names what the cap did, so the two cells read as a
    /// choice between two concrete sessions.
    private var acceptCellTitle: LocalizedStringKey {
        guard display?.kind == .sessionCap else { return "brief.action.accept" }
        switch display?.sessionCap?.shape {
        case .taper: return "verdictCard.cap.cell.taper"
        case .hold:  return "verdictCard.cap.cell.hold"
        default:     return "verdictCard.cap.cell.take"
        }
    }

    // MARK: - 3. Your numbers

    private var yourNumbersBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            RuledSectionHeader(title: "brief.section.numbers")
            VStack(alignment: .leading, spacing: 0) {
                if display?.kind == .sessionCap {
                    sessionCapNumbers
                } else if viewModel.briefExerciseLines.isEmpty {
                    Text("brief.numbers.none")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text2)
                        .padding(.vertical, Spacing.xs)
                } else {
                    ForEach(Array(viewModel.briefExerciseLines.enumerated()), id: \.element.id) { index, line in
                        if index > 0 { RowSeparator() }
                        exerciseLineRow(line)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .cardStyle(horizontalPadding: 0, verticalPadding: 0)
        }
    }

    private func exerciseLineRow(_ line: BriefExerciseLine) -> some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(verbatim: line.exerciseName)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .lineLimit(1)
                Spacer(minLength: Spacing.xs)
                Text(verbatim: adjustedNumbers(line))
                    .font(.Tokens.label)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.text1)
            }
            if line.hasChange {
                AnnotationLabel(plannedNumbers(line))
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .combine)
    }

    /// The cap day's one line: the athlete's planned session, and what it becomes today.
    private var sessionCapNumbers: some View {
        VStack(alignment: .leading, spacing: Spacing.baselinePair) {
            Text(verbatim: capSentence)
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text1)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("brief.sessionCap")
            if let anchor = capRPEAnchor {
                AnnotationLabel(anchor)
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Start (the screen's ONE ink pill)

    private var startBar: some View {
        VStack(spacing: 0) {
            AreaRule()
            PrimaryActionButton(
                title: "brief.action.start",
                isDisabled: !viewModel.canStartResolvedWorkout
            ) {
                guard let plan = viewModel.resolvedPlanForWorkout else { return }
                startedPlan = plan
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .accessibilityIdentifier("brief.start")
        }
        .background(ColorTokens.background)
    }

    // MARK: - Readings copy

    private var readinessValue: String {
        guard let readings, let score = readings.readinessScore, let zone = readings.readinessZone else {
            return LocalePinnedStrings.localized("brief.value.learning", defaultValue: "Learning", locale: locale)
        }
        return "\(zone.displayName) · \(score)"
    }

    private var readinessNote: String? {
        guard let readings, readings.readinessScore != nil else { return nil }
        return LocalePinnedStrings.localized("brief.note.outOf100", defaultValue: "OF 100", locale: locale)
    }

    private var fatigueValue: String {
        guard let readings, let index = readings.fatigueIndex, let zone = readings.fatigueZone else {
            return LocalePinnedStrings.localized("brief.value.learning", defaultValue: "Learning", locale: locale)
        }
        return "\(fatigueZoneWord(zone)) · \(Int(index.rounded()))"
    }

    /// The former banner's line, demoted to the reading it always was.
    private var fatigueNote: String? {
        guard let zone = readings?.fatigueZone else { return nil }
        switch zone {
        case .low:        return LocalePinnedStrings.localized("brief.note.fatigue.low", defaultValue: "WITHIN YOUR NORMAL RANGE", locale: locale)
        case .elevated:   return LocalePinnedStrings.localized("brief.note.fatigue.elevated", defaultValue: "BUILDING", locale: locale)
        case .high:       return LocalePinnedStrings.localized("brief.note.fatigue.high", defaultValue: "WELL ABOVE YOUR NORMAL", locale: locale)
        case .saturation: return LocalePinnedStrings.localized("brief.note.fatigue.saturation", defaultValue: "AT THE TOP OF YOUR RANGE", locale: locale)
        }
    }

    private func fatigueZoneWord(_ zone: FatigueIndexEngine.FatigueZone) -> String {
        switch zone {
        case .low:        return LocalePinnedStrings.localized("brief.fatigue.low", defaultValue: "Low", locale: locale)
        case .elevated:   return LocalePinnedStrings.localized("brief.fatigue.elevated", defaultValue: "Elevated", locale: locale)
        case .high:       return LocalePinnedStrings.localized("brief.fatigue.high", defaultValue: "High", locale: locale)
        case .saturation: return LocalePinnedStrings.localized("brief.fatigue.saturation", defaultValue: "Very high", locale: locale)
        }
    }

    private var hrvValue: String {
        guard let value = readings?.hrvMs else { return dash }
        return String(
            format: LocalePinnedStrings.localized("brief.unit.ms", defaultValue: "%lld ms", locale: locale),
            Int(value.rounded())
        )
    }

    private var hrvNote: String? {
        baselineNote(today: readings?.hrvMs, baseline: readings?.hrvBaselineMs, unitKey: "brief.unit.msBare")
    }

    private var rhrValue: String {
        guard let value = readings?.rhrBpm else { return dash }
        return String(
            format: LocalePinnedStrings.localized("brief.unit.bpm", defaultValue: "%lld bpm", locale: locale),
            Int(value.rounded())
        )
    }

    private var rhrNote: String? {
        baselineNote(today: readings?.rhrBpm, baseline: readings?.rhrBaselineBpm, unitKey: "brief.unit.bpmBare")
    }

    private var sleepValue: String {
        guard let minutes = readings?.sleepMinutes else { return dash }
        return hoursMinutes(minutes)
    }

    private var sleepNote: String? {
        guard let mean = readings?.sleepRecentMeanMinutes else { return nil }
        return String(
            format: LocalePinnedStrings.localized(
                "brief.note.sleepMean", defaultValue: "14-DAY MEAN %@", locale: locale
            ),
            hoursMinutes(mean)
        )
    }

    private var matchNote: String? {
        guard let days = readings?.matchDaysAway else { return nil }
        switch days {
        case 0:  return LocalePinnedStrings.localized("brief.match.today", defaultValue: "Today", locale: locale)
        case 1:  return LocalePinnedStrings.localized("brief.match.tomorrow", defaultValue: "Tomorrow", locale: locale)
        default:
            return String(
                format: LocalePinnedStrings.localized(
                    "brief.match.inDays", defaultValue: "In %lld days", locale: locale
                ),
                days
            )
        }
    }

    /// "▲ 8 MS VS BASELINE" — a signed reference to the athlete's OWN baseline, never a judgement.
    private func baselineNote(today: Double?, baseline: Double?, unitKey: StaticString) -> String? {
        guard let today, let baseline, baseline > 0 else { return nil }
        let delta = today - baseline
        let glyph = delta >= 0 ? "▲" : "▼"
        let unit = LocalePinnedStrings.localized(unitKey, defaultValue: "", locale: locale)
        let magnitude = abs(delta).rounded()
        let versus = LocalePinnedStrings.localized(
            "brief.note.vsBaseline", defaultValue: "VS BASELINE", locale: locale
        )
        return "\(glyph) \(Int(magnitude))\(unit) \(versus)"
    }

    // MARK: - Verdict copy

    private var verdictHeadline: String {
        guard let display else {
            return LocalePinnedStrings.localized(
                "brief.verdict.none", defaultValue: "No session planned for today.", locale: locale
            )
        }
        switch display.kind {
        case .adjusted:
            return LocalePinnedStrings.localized(
                "brief.verdict.adjusted", defaultValue: "An adjustment to your session today.", locale: locale
            )
        case .asPlanned:
            return LocalePinnedStrings.localized(
                "brief.verdict.asPlanned", defaultValue: "Your session stands as you wrote it.", locale: locale
            )
        case .deferred:
            return LocalePinnedStrings.localized(
                "brief.verdict.deferred", defaultValue: "Going with your plan while the baseline fills in.", locale: locale
            )
        case .sessionCap:
            return capSentence
        }
    }

    private var confirmedLine: String {
        switch viewModel.decisionState {
        case .accepted, .mixed:
            return LocalePinnedStrings.localized(
                "verdictCard.state.accepted", defaultValue: "Using the adjustment", locale: locale
            )
        case .keptPlan:
            return LocalePinnedStrings.localized(
                "verdictCard.state.kept", defaultValue: "Training your plan", locale: locale
            )
        case .pending:
            return ""
        }
    }

    // MARK: - Session-cap copy (always a modulation of THEIR session)

    /// "Your 90-minute run, capped at 60 today · RPE 7" — the athlete's own session first, what it
    /// becomes second, never a session prescribed from nothing.
    private var capSentence: String {
        guard let cap = display?.sessionCap else { return "" }
        let sessionName = display?.headlineExerciseName ?? ""

        guard let plannedMinutes = display?.plannedDurationMinutes else {
            guard let rpe = cap.maxRPE else {
                return String(
                    format: LocalePinnedStrings.localized(
                        "brief.cap.asPlanned", defaultValue: "Your %@, as planned today.", locale: locale
                    ),
                    sessionName
                )
            }
            return String(
                format: LocalePinnedStrings.localized(
                    "brief.cap.rpeOnly", defaultValue: "Your %1$@, at RPE %2$lld or under today.", locale: locale
                ),
                sessionName, rpe
            )
        }

        guard let cappedMinutes = cap.maxDurationMinutes, cappedMinutes < plannedMinutes else {
            guard let rpe = cap.maxRPE else {
                return String(
                    format: LocalePinnedStrings.localized(
                        "brief.cap.minutesAsPlanned", defaultValue: "Your %1$lld-minute %2$@, as planned today.", locale: locale
                    ),
                    plannedMinutes, sessionName
                )
            }
            return String(
                format: LocalePinnedStrings.localized(
                    "brief.cap.minutesRPE",
                    defaultValue: "Your %1$lld-minute %2$@, at RPE %3$lld or under today.",
                    locale: locale
                ),
                plannedMinutes, sessionName, rpe
            )
        }

        guard let rpe = cap.maxRPE else {
            return String(
                format: LocalePinnedStrings.localized(
                    "brief.cap.capped", defaultValue: "Your %1$lld-minute %2$@, capped at %3$lld today.", locale: locale
                ),
                plannedMinutes, sessionName, cappedMinutes
            )
        }
        return String(
            format: LocalePinnedStrings.localized(
                "brief.cap.cappedRPE",
                defaultValue: "Your %1$lld-minute %2$@, capped at %3$lld today · RPE %4$lld.",
                locale: locale
            ),
            plannedMinutes, sessionName, cappedMinutes, rpe
        )
    }

    /// The published CR-10 word the ceiling is read against (Foster 1998) — the same instrument
    /// the finish sheet uses, so one RPE means one thing everywhere in the app.
    private var capRPEAnchor: String? {
        guard let rpe = display?.sessionCap?.maxRPE else { return nil }
        let anchor = SessionRPEScale.anchor(for: rpe)
        let word = LocalePinnedStrings.localized(
            String.LocalizationValue(anchor.keyName), locale: locale
        )
        return String(
            format: LocalePinnedStrings.localized(
                "brief.cap.anchor", defaultValue: "RPE %1$lld · %2$@", locale: locale
            ),
            rpe, word
        )
    }

    // MARK: - Number formatting

    private var dash: String { "—" }

    private func hoursMinutes(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        return String(
            format: LocalePinnedStrings.localized(
                "brief.unit.hoursMinutes", defaultValue: "%1$lldh %2$02lldm", locale: locale
            ),
            total / 60, total % 60
        )
    }

    private func adjustedNumbers(_ line: BriefExerciseLine) -> String {
        var parts: [String] = []
        let kg = line.suggestedTopSetKg ?? line.plannedTopSetKg
        if let kg {
            parts.append(WeightFormatter.display(kg, unit: weightUnit, locale: locale))
        }
        parts.append(String(
            format: LocalePinnedStrings.localized("brief.numbers.sets", defaultValue: "× %lld", locale: locale),
            line.suggestedWorkingSets
        ))
        if let rpe = line.suggestedRPE ?? line.plannedRPE {
            parts.append(String(
                format: LocalePinnedStrings.localized("brief.numbers.rpe", defaultValue: "RPE %@", locale: locale),
                rpeText(rpe)
            ))
        }
        return parts.joined(separator: " · ")
    }

    private func plannedNumbers(_ line: BriefExerciseLine) -> String {
        var parts: [String] = []
        if let kg = line.plannedTopSetKg {
            parts.append(WeightFormatter.display(kg, unit: weightUnit, locale: locale))
        }
        parts.append(String(
            format: LocalePinnedStrings.localized("brief.numbers.sets", defaultValue: "× %lld", locale: locale),
            line.plannedWorkingSets
        ))
        if let rpe = line.plannedRPE {
            parts.append(String(
                format: LocalePinnedStrings.localized("brief.numbers.rpe", defaultValue: "RPE %@", locale: locale),
                rpeText(rpe)
            ))
        }
        let planned = LocalePinnedStrings.localized(
            "brief.numbers.planned", defaultValue: "PLANNED", locale: locale
        )
        return "\(planned) \(parts.joined(separator: " · "))"
    }

    private func rpeText(_ rpe: Double) -> String {
        rpe.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", rpe)
            : String(format: "%.1f", rpe)
    }
}
