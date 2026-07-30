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
                    // Editorial screen header (Stage 4a) — in-content title, not stock nav chrome.
                    ScreenHeader(title: "recovery.nav.title")

                    if todayCheckIn == nil {
                        MorningCheckInPrompt {
                            showMorningCheckIn = true
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.bottom, Spacing.sm)
                        .transition(.opacity)
                        .entranceReveal()
                    }

                    RecoveryScoreCard(
                        recovery: todayRecovery,
                        wellnessScore: todayCheckIn?.wellnessScore
                    )
                        .padding(.horizontal, Spacing.sm)
                        .entranceReveal(index: 1)
                        .accessibilityIdentifier("recovery.scoreCard")

                    RuledSection(header: "recovery.section.hrvTrend") {
                        HRVTrendChart(data: viewModel.hrvHistory)
                            .cardStyle()
                            .padding(.horizontal, Spacing.sm)
                    }
                    .entranceReveal(index: 2)

                    RuledSection(header: "recovery.section.sleepTrend") {
                        SleepTrendChart(recoverySnapshots: Array(scopedRecoverySnapshots.prefix(28).reversed()))
                            .cardStyle()
                            .padding(.horizontal, Spacing.sm)
                    }
                    .entranceReveal(index: 3)

                    if !scopedWellnessCheckIns.isEmpty {
                        RuledSection(header: "recovery.section.wellnessCheckIns") {
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
                            RuledSection(header: "recovery.section.insights") {
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
                            RuledSection(header: "recovery.section.behaviorImpact") {
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
                        RuledSection(header: "recovery.section.insights") {
                            DataSufficiencyRing(
                                progress: 0,
                                label: String(localized: "recovery.section.insights.prompt", defaultValue: "Tag behaviors in your morning check-in to see recovery impact"),
                                message: ""
                            )
                            .frame(maxWidth: .infinity)
                            .cardStyle(verticalPadding: Spacing.sm)
                            .padding(.horizontal, Spacing.sm)
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
            .contentMargins(.top, Spacing.md, for: .scrollContent)
            .contentMargins(.bottom, Spacing.lg, for: .scrollContent)
            .background(ColorTokens.background)
            .toolbar(.hidden, for: .navigationBar)
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

    /// The score band of the current recovery zone — the TickScale zone band (ink on light).
    private func zoneBand(for zone: RecoveryZone) -> ClosedRange<Double> {
        switch zone {
        case .red:    return 0...34
        case .yellow: return 34...66
        case .green:  return 66...100
        }
    }

    var body: some View {
        // Hero Law + Reading Color Rule v6: this screen's ONE hero reading is the recovery
        // score, so it takes the readiness hue (DESIGN.md maps `metric-readiness` to
        // "readiness / recovery score"). Everything else on the screen stays in ink — one
        // colored text element per screen. Its designed peak is the score readout on a raised
        // light plane — baseline-aligned score + zone, then a compact TickScale placing the
        // reading on a 0–100 track — with the wearable contributors demoted to a scannable
        // metric grid below.
        VStack(alignment: .leading, spacing: Spacing.sm) {
            heroPlane
            if let recovery {
                metricGrid(for: recovery)
            }
        }
    }

    private var heroPlane: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
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
                // Baseline readout: score dominant left, zone pinned to the trailing edge on
                // the score's baseline. The reading takes its metric's hue (readiness green) —
                // legal on any plane at 32pt, and this is a raised card plane anyway. The
                // "/ 100" denominator is marginalia, so it moves to the annotation voice.
                HStack(alignment: .lastTextBaseline, spacing: Spacing.xs) {
                    Text("\(Int(recovery.recoveryScore))")
                        .font(.Tokens.displayAction)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.metricReadiness)
                    AnnotationLabel("/ 100", color: ColorTokens.text2)
                        .annotationReveal()
                    Spacer(minLength: Spacing.sm)
                    ZoneBadge(
                        label: recovery.zone.displayName,
                        color: ColorTokens.recoveryZoneColor(recovery.zone)
                    )
                }

                // The designed peak: a compact instrument scale placing the score on a 0–100
                // track with the current zone band and the accent needle (live-state mark).
                // Recovery's instrument moment on the stone plane.
                TickScale(
                    range: 0...100,
                    value: recovery.recoveryScore,
                    zone: zoneBand(for: recovery.zone),
                    variant: .micro,
                    theme: .light,
                    accessibilityLabel: Text(verbatim: "\(Int(recovery.recoveryScore)) / 100 · \(recovery.zone.displayName)")
                )

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
                            .font(.Tokens.smallLabelMedium)
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

    /// The wearable contributors (HRV / RHR / Sleep) as the demo-§3 metric grid — scannable
    /// tabular readouts with unit superscripts, standalone below the hero plane so the cells
    /// read as their own instruments rather than plate-in-plate. Each is conditional on its datum.
    @ViewBuilder
    private func metricGrid(for recovery: RecoverySnapshot) -> some View {
        let hasAny = recovery.hrvSDNN != nil || recovery.restingHR != nil || recovery.sleepDurationMinutes != nil
        if hasAny {
            HStack(alignment: .top, spacing: Spacing.xs) {
                if let hrv = recovery.hrvSDNN {
                    MetricCell(label: "HRV", value: "\(Int(hrv))", unit: "ms")
                }
                if let rhr = recovery.restingHR {
                    MetricCell(label: "RHR", value: "\(Int(rhr))", unit: "bpm")
                }
                if let sleep = recovery.sleepDurationMinutes {
                    MetricCell(label: "Sleep", value: Date.durationString(seconds: Int(sleep) * 60, locale: locale))
                }
            }
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
                        .font(.Tokens.smallLabelMedium)
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

// MARK: - Ruled section wrapper

/// Mirrors `SectionContainer` (32pt break gap + header + 16pt gap + content) but headers the
/// section with the demo-§3 `RuledSectionHeader` (micro-caps + trailing hairline) instead of
/// the 19pt `SectionHeader`. The header carries no padding of its own, so it is inset 16pt
/// here to align flush with the cards below it.
private struct RuledSection<Content: View>: View {
    let header: LocalizedStringKey
    var topGap: CGFloat = Spacing.lg
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: topGap)
            RuledSectionHeader(title: header)
                .padding(.horizontal, Spacing.sm)
            Spacer().frame(height: Spacing.sm)
            content
        }
    }
}
