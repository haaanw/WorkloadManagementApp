import SwiftUI
import SwiftData

struct RecoveryView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var athletes: [Athlete]
    @Query(sort: \RecoverySnapshot.date, order: .reverse)
    private var recoverySnapshots: [RecoverySnapshot]
    @Query(sort: \WellnessCheckIn.date, order: .reverse)
    private var wellnessCheckIns: [WellnessCheckIn]
    @State private var showMorningCheckIn = false
    @State private var viewModel = RecoveryViewModel()

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if todayCheckIn == nil {
                        MorningCheckInPrompt {
                            showMorningCheckIn = true
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.top, Spacing.sm)
                        .transition(.opacity)
                        .entranceReveal()
                    }

                    RecoveryScoreCard(
                        recovery: todayRecovery,
                        wellnessScore: todayCheckIn?.wellnessScore
                    )
                        .padding(.horizontal, Spacing.sm)
                        .padding(.top, Spacing.sm)
                        .entranceReveal(index: 1)

                    SectionContainer(header: "recovery.section.hrvTrend") {
                        HRVTrendChart(data: viewModel.hrvHistory)
                            .cardStyle()
                            .padding(.horizontal, Spacing.sm)
                    }
                    .entranceReveal(index: 2)

                    SectionContainer(header: "recovery.section.sleepTrend") {
                        SleepTrendChart(recoverySnapshots: Array(scopedRecoverySnapshots.prefix(28).reversed()))
                            .cardStyle()
                            .padding(.horizontal, Spacing.sm)
                    }
                    .entranceReveal(index: 3)

                    if !scopedWellnessCheckIns.isEmpty {
                        SectionContainer(header: "recovery.section.wellnessCheckIns") {
                            WellnessHistorySection(checkIns: Array(scopedWellnessCheckIns.prefix(7)))
                                .padding(.horizontal, Spacing.sm)
                        }
                        .transition(.opacity)
                        .entranceReveal(index: 4)
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
                            .transition(.opacity)
                            .entranceReveal(index: 5)
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
                            .transition(.opacity)
                            .entranceReveal(index: 6)
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
                        .transition(.opacity)
                        .entranceReveal(index: 5)
                    }

                    Spacer().frame(height: Spacing.lg)
                }
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: viewModel.isLoading)
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: todayCheckIn == nil)
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: scopedWellnessCheckIns.isEmpty)
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: viewModel.fatigueInsights.count)
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: viewModel.behaviorCorrelations.count)
            }
            .contentMargins(.bottom, Spacing.lg, for: .scrollContent)
            .background(ColorTokens.background)
            .navigationTitle("recovery.nav.title")
            .toolbarBackground(ColorTokens.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
            modelContext: modelContext
        )
    }
}

// MARK: - Morning Check-in Prompt

struct MorningCheckInPrompt: View {
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.baselinePair) {
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
        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
        .foregroundStyle(ColorTokens.text1)
    }
}

// MARK: - Recovery Score Card

struct RecoveryScoreCard: View {
    let recovery: RecoverySnapshot?
    /// Today's subjective wellness check-in score (the how-you-feel part alone), read-only.
    /// Already feeds the composite recoveryScore at 25% in RecoveryScoreEngine — surfaced here
    /// only as a subordinate label, never re-computed or re-fused (B.2 honest blend).
    var wellnessScore: Double? = nil
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("recovery.section.recoveryScore")
                .font(.Tokens.sectionHead)
                .foregroundStyle(ColorTokens.text1)

            // Honest blend subtitle (B.2): the composite score already combines wearable
            // signals with how-you-feel — copy must not claim it is wearable-only.
            Text("recovery.blend.subtitle")
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let recovery {
                HStack(alignment: .lastTextBaseline) {
                    Text("\(Int(recovery.recoveryScore))")
                        .font(.Tokens.pageTitle)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.accent)
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

                // "How you feel" element (B.2): surface today's subjective wellness score as a
                // DISTINCT, subordinate labeled row — NOT a second zone-badge hero. Read-only
                // from today's existing check-in; no new score math. Shown only when present.
                if let wellnessScore {
                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    HStack {
                        Text("recovery.feel.label")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                        Spacer()
                        Text("\(Int(wellnessScore))/100")
                            .font(.Tokens.label)
                            .monospacedDigit()
                            .foregroundStyle(ColorTokens.text1)
                    }

                    // Low-emphasis "why these differ" note: recovery = wearable + how-you-feel
                    // combined; this score = the how-you-feel part alone.
                    Text("recovery.feel.note")
                        .font(.Tokens.micro)
                        .foregroundStyle(ColorTokens.text3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("recovery.empty.body")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }
        }
        .emphasisCardStyle()
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
        }
        .cardStyle(horizontalPadding: 0, verticalPadding: 0)
    }
}
