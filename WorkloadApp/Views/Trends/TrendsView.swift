import SwiftUI
import SwiftData

/// The Trends tab, re-scoped in v1.7.3 (UAT round 1 · U9) around the FATIGUE NARRATIVE.
///
/// It arrived here in two steps. Slice 3 merged the Recovery and Load tabs, which were
/// read-only exhibits duplicating Home's readings, into one page of trend charts. HAN's round-1
/// verdict on that page was that it carried no insight: seven charts and not one sentence, two
/// of them re-plotting HRV and sleep readings Today already prints. So the page now answers the
/// one over-time question the product is built for — **what have the last weeks added up to in
/// my fatigue budget** — and the physiology lines left for the metric cells that name them
/// (Today's HRV / RHR / sleep cells each push their own detail screen since this same pass).
///
/// Order: range rail → fatigue (hero, with its accumulation series and trajectory) → load →
/// what you did → the carried-over sections (Pro recovery-vs-load, check-ins, insights, PRs).
///
/// **Claim rails.** The fatigue copy describes accumulation and trajectory — readings of stored
/// values and counts against the athlete's own baseline. It never names an injury risk, never
/// forecasts, and never prescribes: Trends describes, Today decides.
///
/// Free-tier gating carries over EXACTLY, and nothing here re-prices anything: the history
/// window filter + teaser, the Pro-only range control, the Pro-only Recovery-vs-Load chart, the
/// 7-day free PR window, and the export gate. The fatigue series deliberately reads the
/// athlete's full history — Today's fatigue banner already does, and a filtered hero would make
/// the two tabs contradict each other about the same number on the same day.
struct TrendsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Query private var athletes: [Athlete]
    @Query(sort: \WellnessCheckIn.date, order: .reverse)
    private var wellnessCheckIns: [WellnessCheckIn]
    @Query(sort: \WorkloadSnapshot.snapshotDate, order: .reverse)
    private var workloadSnapshots: [WorkloadSnapshot]
    @Query(sort: \PersonalRecord.achievedAt, order: .reverse)
    private var personalRecords: [PersonalRecord]
    @Query(sort: \WorkoutSession.sessionDate, order: .reverse)
    private var allSessions: [WorkoutSession]

    @State private var viewModel = TrendsViewModel()
    @State private var selectedTrendDate: Date?
    @State private var showUpgrade = false
    @State private var showExportOptions = false
    @State private var showShareSheet = false
    @State private var showUpgradeForExport = false
    @State private var exportFileURL: URL?
    @State private var showPDFSheet = false

    private var athlete: Athlete? { athletes.first }

    // MARK: Scoped queries

    private var scopedWellnessCheckIns: [WellnessCheckIn] {
        guard let athleteId = athlete?.id else { return [] }
        return wellnessCheckIns.filter { $0.athlete?.id == athleteId }
    }

    private var scopedWorkloadSnapshots: [WorkloadSnapshot] {
        guard let athleteId = athlete?.id else { return [] }
        return workloadSnapshots.filter { $0.athlete?.id == athleteId }
    }

    private var scopedPersonalRecords: [PersonalRecord] {
        guard let athleteId = athlete?.id else { return [] }
        return personalRecords.filter { $0.athlete?.id == athleteId }
    }

    private var scopedSessions: [WorkoutSession] {
        guard let athleteId = athlete?.id else { return [] }
        return allSessions.filter { $0.athlete?.id == athleteId }
    }

    // MARK: Free-tier gating (carried over from the retired Load tab, unchanged)

    private var visibleSnapshots: [WorkloadSnapshot] {
        container.subscriptionService.isPro
            ? scopedWorkloadSnapshots
            : SubscriptionService.filterSnapshotsForFree(scopedWorkloadSnapshots)
    }

    private var lockedWeeks: Int {
        guard !container.subscriptionService.isPro else { return 0 }
        let visible = SubscriptionService.filterSnapshotsForFree(scopedWorkloadSnapshots)
        return SubscriptionService.lockedWeeks(
            totalSessions: scopedWorkloadSnapshots.count,
            visibleSessions: visible.count
        )
    }

    private var visibleRecords: [PersonalRecord] {
        guard !container.subscriptionService.isPro else { return Array(scopedPersonalRecords.prefix(5)) }
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return scopedPersonalRecords.filter { $0.achievedAt >= cutoff }.prefix(5).map { $0 }
    }

    /// Trend snapshots filtered by the selected time range.
    private var trendData: [WorkloadSnapshot] {
        Array(visibleSnapshots.prefix(viewModel.selectedRange.days).reversed())
    }

    // The sleep-glance window and its HealthKit-nights fetch left with the glance chart
    // (v1.7.3 · U9). `SleepDetailScreen` — reached from Today's sleep cell — builds its own.

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Editorial screen header — in-content title; the export action rides
                // its baseline (carried from the retired Load tab, gate unchanged).
                ScreenHeader(title: "trends.nav.title") {
                    Button {
                        Haptics.tap()
                        if container.subscriptionService.isPro {
                            showExportOptions = true
                        } else {
                            showUpgradeForExport = true
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                    }
                    .accessibilityLabel("a11y.exportWorkoutData")
                    .accessibilityIdentifier("export.workoutData")
                    .buttonStyle(.pressable)
                }
                .padding(.top, Spacing.md)

                // The range rail is the page's spine, so it sits under the header rather than
                // inside a section — the Log tab's filter-rail position, bracketed by the same
                // area hairlines. It stays PRO, exactly as the retired Load tab's range control
                // was: a free athlete reads the default fortnight, which is the fatigue model's
                // own window.
                if container.subscriptionService.isPro {
                    AreaRule()
                    TrendsRangeRail(selected: $viewModel.selectedRange)
                    AreaRule()
                }

                ScrollView {
                    VStack(spacing: 0) {
                        // 1. Fatigue — the hero, and the reason this page exists.
                        RuledSection(header: "trends.section.fatigue", topGap: Spacing.sm) {
                            TrendsFatigueSection(
                                points: viewModel.fatiguePoints,
                                trajectory: viewModel.trajectory,
                                daysWithoutRelief: viewModel.daysWithoutRelief,
                                observedHistoryDays: viewModel.observedHistoryDays,
                                hasEnoughHistory: viewModel.hasEnoughHistory,
                                rangeDays: viewModel.selectedRange.days
                            )
                            .padding(.horizontal, Spacing.sm)
                        }
                        .entranceReveal()

                        // 2. Load — acute ÷ chronic, its chart, and the range actually held.
                        RuledSection(header: "trends.section.load") {
                            TrendsLoadSection(
                                snapshot: viewModel.latestLoadSnapshot,
                                acwrRange: viewModel.acwrRange,
                                trendSnapshots: trendData,
                                selectedTrendDate: $selectedTrendDate
                            )
                            .padding(.horizontal, Spacing.sm)
                        }
                        .entranceReveal(index: 1)

                        // 3. What you did — sessions against the athlete's own average.
                        RuledSection(header: "trends.section.activity") {
                            TrendsWhatYouDidSection(
                                sessionCount: viewModel.sessionsInRange,
                                baselineSessions: viewModel.baselineSessionsInRange,
                                bars: viewModel.dailyLoadBars,
                                typeCounts: viewModel.sessionTypeCounts,
                                rangeDays: viewModel.selectedRange.days
                            )
                            .padding(.horizontal, Spacing.sm)
                        }
                        .entranceReveal(index: 2)

                        if lockedWeeks > 0 {
                            SectionContainer {
                                HistoryTeaserBanner(lockedWeeks: lockedWeeks) {
                                    showUpgrade = true
                                }
                                .padding(.horizontal, Spacing.sm)
                            }
                            .transition(.opacity)
                            .entranceReveal(index: 3)
                        }

                        // The Pro chart stays Pro (closure-plan law).
                        if container.subscriptionService.isPro {
                            RuledSection(header: "workload.section.recoveryVsLoad") {
                                RecoveryLoadChart(
                                    loadSnapshots: viewModel.correlationLoadSnapshots,
                                    recoverySnapshots: viewModel.correlationRecoverySnapshots
                                )
                                .cardStyle()
                                .padding(.horizontal, Spacing.sm)
                            }
                            // v6.3: a RECOVERY surface sitting on a load screen — the section
                            // owns the recovery hue, so its rule reads as recovery while the
                            // page around it reads as load. Ownership follows the metric, not
                            // the tab. (This is the inversion of what the load trend used to do
                            // here, and it moved for the same reason: the page's hero changed.)
                            .metricArea(.recovery)
                            .transition(.opacity)
                            .entranceReveal(index: 4)
                        }

                        if !scopedWellnessCheckIns.isEmpty {
                            RuledSection(header: "recovery.section.wellnessCheckIns") {
                                WellnessHistorySection(checkIns: Array(scopedWellnessCheckIns.prefix(7)))
                                    .padding(.horizontal, Spacing.sm)
                            }
                            .transition(.opacity)
                            .entranceReveal(index: 5)
                        }

                        // INSIGHTS section (INTEL-05, D-07) — carried from the retired
                        // Recovery tab unchanged.
                        if !viewModel.fatigueInsights.isEmpty || !viewModel.behaviorCorrelations.isEmpty || !viewModel.behaviorSufficiency.isEmpty {
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
                                .entranceReveal(index: 6)
                            }

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
                                .entranceReveal(index: 7)
                            }
                        } else if viewModel.recoveryHistory.count > 7 {
                            // Has some recovery data but no insights yet — show encouragement
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
                            .entranceReveal(index: 6)
                        }

                        if !visibleRecords.isEmpty {
                            RuledSection(header: "workload.section.recentPRs") {
                                PRHistorySection(records: visibleRecords)
                                    .padding(.horizontal, Spacing.sm)
                            }
                            .transition(.opacity)
                            .entranceReveal(index: 8)
                        }

                        Spacer().frame(height: Spacing.lg)
                    }
                    .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: viewModel.isLoading)
                    .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: lockedWeeks)
                    .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: visibleRecords.count)
                    .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: scopedWellnessCheckIns.isEmpty)
                    .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: viewModel.fatigueInsights.count)
                    .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: viewModel.behaviorCorrelations.count)
                }
                .contentMargins(.bottom, Spacing.lg, for: .scrollContent)
                .background(ColorTokens.background)
            }
            // On the VStack, not just the ScrollView: the header and the range rail above it
            // would otherwise render on the system's pure white (the Log tab's own finding).
            .background(ColorTokens.background)
            // v6.3 "The Area Tint": with the re-scope this became a LOAD surface. The page's
            // hero is the fatigue index — an accumulation reading in the load hue — so the tint
            // follows the metric, as the ownership map requires. It was `.recovery` while the
            // page was a chart exhibit fronted by HRV; that reading left with the glance charts.
            // The recovery-vs-load section declares `.metricArea(.recovery)` on ITSELF below,
            // the way the load trend used to declare its own hue here.
            .metricArea(.load)
            .toolbar(.hidden, for: .navigationBar)
            // Same destination enum Home routes on, so both tabs land on the SAME
            // self-fetching screens (`TrendDetailScreens` — the one fetch path).
            .navigationDestination(for: TrendDestination.self) { destination in
                switch destination {
                case .hrv:   HRVDetailScreen()
                case .rhr:   RHRDetailScreen()
                case .sleep: SleepDetailScreen()
                }
            }
            .confirmationDialog("workload.export.title", isPresented: $showExportOptions, titleVisibility: .visible) {
                Button("workload.export.sessionSummary") {
                    exportCSV(format: .sessionSummary)
                }
                Button("workload.export.detailedSets") {
                    exportCSV(format: .detailedSets)
                }
                Button("workload.export.pdfReport") {
                    showPDFSheet = true
                }
                .accessibilityIdentifier("export.pdfReport")
                Button("action.cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportFileURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showPDFSheet) {
                PDFGenerationSheet()
            }
            .sheet(isPresented: $showUpgradeForExport) {
                UpgradeSheet(trigger: .export)
            }
            .sheet(isPresented: $showUpgrade) {
                UpgradeSheet(trigger: .history(lockedWeeks: lockedWeeks))
            }
            .task {
                await loadData()
            }
            // `.task` runs once per appearance — after an overnight background the screen
            // would still believe it was yesterday (the RecoveryView idiom, v1.7.1). Both
            // hooks call the same idempotent load.
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await loadData() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                Task { await loadData() }
            }
            .onChange(of: viewModel.selectedRange) { _, _ in
                // `trendData` re-slices reactively from the query, but the fatigue series and
                // the activity read are COMPUTED over the window — they have to be rebuilt, or
                // the rail would move the load chart and leave the hero on the old fortnight.
                // The rail's own haptic marks the commit; this is the work behind it.
                Task { await loadData() }
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

    // MARK: - Export (carried from the retired Load tab, unchanged)

    private enum ExportFormat {
        case sessionSummary
        case detailedSets
    }

    private func exportCSV(format: ExportFormat) {
        let csvString: String
        let filename: String
        let dateString = Date.now.formatted(.dateTime.year().month().day())

        switch format {
        case .sessionSummary:
            csvString = CSVExportEngine.sessionSummaryCSV(sessions: scopedSessions)
            filename = "tuwa_sessions_\(dateString).csv"
        case .detailedSets:
            csvString = CSVExportEngine.detailedSetsCSV(sessions: scopedSessions)
            filename = "tuwa_sets_\(dateString).csv"
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            exportFileURL = tempURL
            showShareSheet = true
        } catch {
            print("CSV export error: \(error)")
        }
    }
}

// MARK: - Ruled section wrapper

/// Mirrors `SectionContainer` (32pt break gap + header + 16pt gap + content) but headers the
/// section with the demo-§3 `RuledSectionHeader` (micro-caps + trailing hairline) instead of
/// the 19pt `SectionHeader`. The header carries no padding of its own, so it is inset 16pt
/// here to align flush with the cards below it. (Same private wrapper the retired
/// RecoveryView carried — private types are file-scoped, so this is a sibling, not a fork.)
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
