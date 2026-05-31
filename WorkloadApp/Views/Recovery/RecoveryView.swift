import SwiftUI
import SwiftData

struct RecoveryView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]
    @Query(sort: \RecoverySnapshot.date, order: .reverse)
    private var recoverySnapshots: [RecoverySnapshot]
    @Query(sort: \WellnessCheckIn.date, order: .reverse)
    private var wellnessCheckIns: [WellnessCheckIn]
    @Query private var cycleSnapshots: [MenstrualCycleSnapshot]
    @State private var showMorningCheckIn = false
    @State private var viewModel = RecoveryViewModel()
    // RED-S banner dismissal persisted per coarse period (month) so it does not nag daily
    // but can re-surface if the pattern persists into a new cycle (D-13).
    @AppStorage("redsBannerDismissedPeriod") private var redsDismissedPeriod: String = ""

    private var athlete: Athlete? { athletes.first }

    private var scopedRecoverySnapshots: [RecoverySnapshot] {
        guard let athleteId = athlete?.id else { return [] }
        return recoverySnapshots.filter { $0.athlete?.id == athleteId }
    }

    private var scopedWellnessCheckIns: [WellnessCheckIn] {
        guard let athleteId = athlete?.id else { return [] }
        return wellnessCheckIns.filter { $0.athlete?.id == athleteId }
    }

    private var todayCheckIn: WellnessCheckIn? {
        scopedWellnessCheckIns.first { Calendar.current.isDateInToday($0.date) }
    }

    private var todayRecovery: RecoverySnapshot? {
        scopedRecoverySnapshots.first { Calendar.current.isDateInToday($0.date) }
    }

    // MARK: - Cycle context (CYCLE-06/07/08)

    /// Athlete-scoped cycle snapshots, newest first.
    private var scopedCycleSnapshots: [MenstrualCycleSnapshot] {
        guard let athleteId = athlete?.id else { return [] }
        return cycleSnapshots
            .filter { $0.athlete?.id == athleteId }
            .sorted { $0.date > $1.date }
    }

    /// Latest cycle snapshot (D-02). Nil when no HealthKit menstrual data (SC6 — UI invisible).
    private var latestCycleSnapshot: MenstrualCycleSnapshot? {
        scopedCycleSnapshots.first
    }

    /// D-03/D-04 interpretation gate — phase context + fueling only when high-confidence,
    /// non-unknown phase, and no exclusion (mirrors the Phase 18 engine gate).
    private func cycleGatePasses(_ snapshot: MenstrualCycleSnapshot) -> Bool {
        snapshot.confidence >= 0.7
            && (snapshot.estimatedPhase ?? .unknown) != .unknown
            && !(snapshot.isOnHormonalContraceptive || snapshot.isPregnant || snapshot.isLactating)
    }

    /// Derive the pure RED-S engine input from local snapshots + athlete exclusion flags (D-10/D-11).
    /// All cycle math is done here (view layer); the engine stays pure (D-14).
    private var redsRiskState: REDSRiskEngine.RiskState {
        let calendar = Calendar.current
        // Cycle-start dates ascending (mirror CycleTrackingService cycle-start handling).
        let startDates = scopedCycleSnapshots
            .filter { $0.isCycleStart }
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()

        // Cycle lengths = day-diffs between consecutive starts (most-recent last).
        var lengths: [Int] = []
        if startDates.count >= 2 {
            for i in 1..<startDates.count {
                if let days = calendar.dateComponents([.day], from: startDates[i - 1], to: startDates[i]).day {
                    lengths.append(days)
                }
            }
        }

        let median: Int? = {
            guard !lengths.isEmpty else { return nil }
            let sorted = lengths.sorted()
            let mid = sorted.count / 2
            return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
        }()

        let daysSinceLastStart = startDates.last.flatMap {
            calendar.dateComponents([.day], from: $0, to: .now).day
        }

        let input = REDSRiskEngine.CycleHistoryInput(
            recentCycleLengths: lengths,
            medianCycleLength: median,
            daysSinceLastCycleStart: daysSinceLastStart,
            hasSnapshotData: !scopedCycleSnapshots.isEmpty,
            isPregnant: athlete?.isPregnant ?? false,
            isLactating: athlete?.isLactating ?? false,
            isOnHormonalContraceptive: athlete?.isOnHormonalContraceptive ?? false,
            hasPCOS: athlete?.hasPCOS ?? false,
            isPerimenopausal: athlete?.isPerimenopausal ?? false
        )
        return REDSRiskEngine.classify(input: input)
    }

    private var currentPeriodKey: String {
        let comps = Calendar.current.dateComponents([.year, .month], from: .now)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)"
    }

    private var showREDSBanner: Bool {
        redsRiskState == .monitor && redsDismissedPeriod != currentPeriodKey
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Non-diagnostic RED-S monitoring notice (CYCLE-08, D-12/D-13).
                    // Only when the pure engine returns .monitor and not dismissed this period.
                    if showREDSBanner {
                        REDSAttentionBanner(onDismiss: {
                            redsDismissedPeriod = currentPeriodKey
                        })
                        .padding(.horizontal, Spacing.sm)
                        .padding(.top, Spacing.sm)
                    }

                    if todayCheckIn == nil {
                        MorningCheckInPrompt {
                            showMorningCheckIn = true
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.top, Spacing.sm)
                    }

                    RecoveryScoreCard(recovery: todayRecovery, cycleSnapshot: latestCycleSnapshot)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.top, Spacing.sm)

                    // Cycle-aware fueling & recovery suggestions (CYCLE-07, D-08).
                    // Only when cycle data exists and the D-03 phase gate passes.
                    if let snap = latestCycleSnapshot, cycleGatePasses(snap) {
                        SectionContainer {
                            CycleFuelingCard(phase: snap.estimatedPhase ?? .unknown)
                                .padding(.horizontal, Spacing.sm)
                        }
                    }

                    SectionContainer(header: "recovery.section.hrvTrend") {
                        HRVTrendChart(data: viewModel.hrvHistory)
                            .cardStyle()
                            .padding(.horizontal, Spacing.sm)
                    }

                    SectionContainer(header: "recovery.section.sleepTrend") {
                        SleepTrendChart(recoverySnapshots: Array(scopedRecoverySnapshots.prefix(28).reversed()))
                            .cardStyle()
                            .padding(.horizontal, Spacing.sm)
                    }

                    if !scopedWellnessCheckIns.isEmpty {
                        SectionContainer(header: "recovery.section.wellnessCheckIns") {
                            WellnessHistorySection(checkIns: Array(scopedWellnessCheckIns.prefix(7)))
                        }
                    }

                    // INSIGHTS section (INTEL-05, D-07)
                    if !viewModel.fatigueInsights.isEmpty || !viewModel.behaviorCorrelations.isEmpty || !viewModel.behaviorSufficiency.isEmpty {
                        // Fatigue insights
                        if !viewModel.fatigueInsights.isEmpty {
                            SectionContainer(header: "recovery.section.insights") {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    ForEach(Array(viewModel.fatigueInsights.prefix(5).enumerated()), id: \.offset) { _, insight in
                                        InsightCard(text: insight.text, sampleSize: insight.sampleSize)
                                    }
                                }
                                .padding(.horizontal, Spacing.sm)
                            }
                        }

                        // Behavior impact
                        if !viewModel.behaviorCorrelations.isEmpty || !viewModel.behaviorSufficiency.isEmpty {
                            SectionContainer(header: "recovery.section.behaviorImpact") {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    // Sufficient correlations first
                                    ForEach(viewModel.behaviorCorrelations.filter { $0.isSufficient }, id: \.tagName) { correlation in
                                        BehaviorCorrelationRow(
                                            tagName: correlation.tagName,
                                            impactPercentage: correlation.impactPercentage,
                                            sampleCountWith: correlation.sampleCountWith,
                                            sampleCountWithout: correlation.sampleCountWithout,
                                            isSufficient: true,
                                            neededDays: 0
                                        )
                                    }

                                    // Insufficient tags below
                                    ForEach(viewModel.behaviorSufficiency.filter { $0.neededWith > 0 || $0.neededWithout > 0 }, id: \.tagName) { info in
                                        BehaviorCorrelationRow(
                                            tagName: info.tagName,
                                            impactPercentage: 0,
                                            sampleCountWith: info.daysWithTag,
                                            sampleCountWithout: info.daysWithoutTag,
                                            isSufficient: false,
                                            neededDays: max(info.neededWith, info.neededWithout)
                                        )
                                    }
                                }
                                .padding(.horizontal, Spacing.sm)
                            }
                        }
                    } else if viewModel.recoveryHistory.count > 7 {
                        // Has some recovery data but no insights yet -- show encouragement
                        SectionContainer(header: "recovery.section.insights") {
                            DataSufficiencyRing(
                                progress: 0,
                                label: String(localized: "recovery.section.insights.prompt", defaultValue: "Tag behaviors in your morning check-in to see recovery impact"),
                                message: ""
                            )
                        }
                    }

                    Spacer().frame(height: Spacing.lg)
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("recovery.nav.title")
            .toolbarBackground(ColorTokens.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .withContextSwitcher()
            .sheet(isPresented: $showMorningCheckIn) {
                MorningCheckInSheet(onSaved: {
                    Task { await onCheckInSaved() }
                })
            }
            .task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        guard let athlete else { return }
        await viewModel.load(
            athlete: athlete,
            healthKitService: container.healthKitService,
            modelContext: modelContext
        )
    }

    private func onCheckInSaved() async {
        guard let athlete else { return }
        await viewModel.onWellnessCheckInSaved(
            athlete: athlete,
            healthKitService: container.healthKitService,
            modelContext: modelContext,
            cycleTrackingService: container.cycleTrackingService
        )
    }
}

// MARK: - Morning Check-in Prompt

struct MorningCheckInPrompt: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("recovery.checkin.title")
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)
                    Text("recovery.checkin.prompt")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
            }
            .cardStyle(verticalPadding: Spacing.sm)
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Recovery Score Card

struct RecoveryScoreCard: View {
    let recovery: RecoverySnapshot?
    var cycleSnapshot: MenstrualCycleSnapshot? = nil
    @Environment(\.locale) private var locale

    /// D-03/D-04 gate for the readiness-first phase-context line.
    private var phaseContextKey: String? {
        guard let snap = cycleSnapshot,
              snap.confidence >= 0.7,
              let phase = snap.estimatedPhase,
              phase != .unknown,
              !(snap.isOnHormonalContraceptive || snap.isPregnant || snap.isLactating)
        else { return nil }
        return phase.contextCopyKey
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("recovery.section.recoveryScore")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)

            if let recovery {
                HStack(alignment: .lastTextBaseline) {
                    Text("\(Int(recovery.recoveryScore))")
                        .font(.Tokens.pageTitle)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text1)
                    Text("/ 100")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                    Spacer()
                    ZoneBadge(
                        label: recovery.zone.displayName,
                        color: ColorTokens.recoveryZoneColor(recovery.zone)
                    )
                }

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)

                VStack(spacing: 8) {
                    if let hrv = recovery.hrvSDNN {
                        RecoveryComponentRow(
                            label: "recovery.label.hrv",
                            value: String(
                                format: String(localized: "recovery.hrv.value", defaultValue: "%lld ms"),
                                locale: locale,
                                Int(hrv)
                            )
                        )
                    }
                    if let rhr = recovery.restingHR {
                        RecoveryComponentRow(
                            label: "recovery.label.restingHR",
                            value: String(
                                format: String(localized: "recovery.rhr.value", defaultValue: "%lld bpm"),
                                locale: locale,
                                Int(rhr)
                            )
                        )
                    }
                    if let sleep = recovery.sleepDurationMinutes {
                        RecoveryComponentRow(
                            label: "recovery.label.sleep",
                            value: Date.durationString(seconds: Int(sleep) * 60, locale: locale)
                        )
                    }
                }

                // Readiness-first phase-context line (CYCLE-06 SC2, D-05). Explains the score
                // in cycle terms; never prescribes training. Only when the D-03 gate passes.
                if let key = phaseContextKey {
                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)
                    Text(LocalizedStringKey(key))
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("recovery.empty.body")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }
        }
        .cardStyle()
    }
}

struct RecoveryComponentRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
            Spacer()
            Text(value)
                .font(.Tokens.label)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
        }
    }
}

// MARK: - Wellness History

struct WellnessHistorySection: View {
    let checkIns: [WellnessCheckIn]
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)

            ForEach(Array(checkIns.enumerated()), id: \.element.id) { index, checkIn in
                HStack {
                    Text(checkIn.date.relativeString(locale: locale))
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                    Spacer()
                    Text("\(Int(checkIn.wellnessScore))/100")
                        .font(.Tokens.label)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text1)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.sm)

                if index < checkIns.count - 1 {
                    RowSeparator()
                }
            }

            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)
        }
        .background(ColorTokens.background)
    }
}
