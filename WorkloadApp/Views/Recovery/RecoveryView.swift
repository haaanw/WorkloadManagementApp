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
                        Rectangle()
                            .fill(ColorTokens.divider)
                            .frame(height: 0.5)
                    }

                    RecoveryScoreCard(recovery: todayRecovery)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    HRVTrendChart(data: viewModel.hrvHistory)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    SleepTrendChart(recoverySnapshots: Array(scopedRecoverySnapshots.prefix(28).reversed()))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)

                    if !scopedWellnessCheckIns.isEmpty {
                        Rectangle()
                            .fill(ColorTokens.divider)
                            .frame(height: 0.5)

                        WellnessHistorySection(checkIns: Array(scopedWellnessCheckIns.prefix(7)))
                    }

                    // INSIGHTS section (INTEL-05, D-07)
                    if !viewModel.fatigueInsights.isEmpty || !viewModel.behaviorCorrelations.isEmpty || !viewModel.behaviorSufficiency.isEmpty {
                        Rectangle()
                            .fill(ColorTokens.divider)
                            .frame(height: 0.5)

                        // Fatigue insights
                        if !viewModel.fatigueInsights.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("INSIGHTS")
                                    .font(.Tokens.micro)
                                    .tracking(1.2)
                                    .textCase(.uppercase)
                                    .foregroundStyle(ColorTokens.text3)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                    .padding(.bottom, 8)

                                ForEach(Array(viewModel.fatigueInsights.prefix(5).enumerated()), id: \.offset) { _, insight in
                                    InsightCard(text: insight.text, sampleSize: insight.sampleSize)
                                }
                            }
                        }

                        // Behavior impact
                        if !viewModel.behaviorCorrelations.isEmpty || !viewModel.behaviorSufficiency.isEmpty {
                            Rectangle()
                                .fill(ColorTokens.divider)
                                .frame(height: 0.5)

                            VStack(alignment: .leading, spacing: 0) {
                                Text("BEHAVIOR IMPACT")
                                    .font(.Tokens.micro)
                                    .tracking(1.2)
                                    .textCase(.uppercase)
                                    .foregroundStyle(ColorTokens.text3)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                    .padding(.bottom, 8)

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
                        }
                    } else if viewModel.recoveryHistory.count > 7 {
                        // Has some recovery data but no insights yet -- show encouragement
                        Rectangle()
                            .fill(ColorTokens.divider)
                            .frame(height: 0.5)

                        VStack(spacing: 0) {
                            Text("INSIGHTS")
                                .font(.Tokens.micro)
                                .tracking(1.2)
                                .textCase(.uppercase)
                                .foregroundStyle(ColorTokens.text3)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .padding(.bottom, 8)

                            DataSufficiencyRing(
                                progress: 0,
                                label: "Tag behaviors in your morning check-in to see recovery impact",
                                message: ""
                            )
                        }
                    }
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("Recovery")
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
                    Text("Morning Check-in")
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)
                    Text("How are you feeling today?")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(ColorTokens.surface)
        }
        .foregroundStyle(.primary)
    }
}

// MARK: - Recovery Score Card

struct RecoveryScoreCard: View {
    let recovery: RecoverySnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("RECOVERY SCORE")
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
                        RecoveryComponentRow(label: "HRV", value: String(format: "%.0f ms", hrv))
                    }
                    if let rhr = recovery.restingHR {
                        RecoveryComponentRow(label: "Resting HR", value: String(format: "%.0f bpm", rhr))
                    }
                    if let sleep = recovery.sleepDurationMinutes {
                        let hours = Int(sleep) / 60
                        let mins = Int(sleep) % 60
                        RecoveryComponentRow(label: "Sleep", value: "\(hours)h \(mins)m")
                    }
                }
            } else {
                Text("No recovery data yet. Complete your morning check-in or connect Apple Health.")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(ColorTokens.surface)
    }
}

struct RecoveryComponentRow: View {
    let label: String
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
            Text("WELLNESS CHECK-INS")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)

            ForEach(checkIns, id: \.id) { checkIn in
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
            }
        }
        .background(ColorTokens.background)
    }
}
