import SwiftUI
import SwiftData

/// The merged Trends tab (v1.7.3 reorientation slice 3 — APP-REORIENTATION §4.2
/// Option A). The Recovery and Load tabs were read-only exhibits that duplicated Home's
/// readings (appendix §6): the recovery hero re-rendered Home's hero, the ACWR gauge and
/// ATL/CTL/TSB grid re-rendered Home's `TrainingLoadSection` cells. This screen keeps
/// what those tabs alone carried — the trend charts, histories, and insights — and
/// retires the duplicated current-readings; Home owns "now", Trends owns "over time".
///
/// Free-tier gating carries over from the retired tabs EXACTLY: the history window
/// filter + teaser, the Pro-only range control, the Pro-only Recovery-vs-Load chart,
/// the 7-day free PR window, and the export gate.
struct TrendsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Query private var athletes: [Athlete]
    @Query(sort: \RecoverySnapshot.date, order: .reverse)
    private var recoverySnapshots: [RecoverySnapshot]
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
    /// HealthKit-derived nights (v1.7.1 round 2) — the sleep glance draws these when
    /// present; persisted snapshots (pre-fix inflated values and gaps) are the fallback.
    /// `fetchSleepNights` is not on the `HealthDataProviding` seam, so the fetch lives
    /// at the call site (the RecoveryView precedent).
    @State private var hkSleepNights: [SleepSessionMath.NightSummary] = []

    private var athlete: Athlete? { athletes.first }

    // MARK: Scoped queries

    private var scopedRecoverySnapshots: [RecoverySnapshot] {
        guard let athleteId = athlete?.id else { return [] }
        return recoverySnapshots.filter { $0.athlete?.id == athleteId }
    }

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

    // MARK: Sleep glance window (carried over from the retired Recovery tab)

    /// The 28-day window (oldest first) the sleep glance chart reads as its snapshot
    /// fallback — the detail screen (`SleepDetailScreen`) builds its own window.
    private var sleepWindow: [RecoverySnapshot] {
        Array(scopedRecoverySnapshots.prefix(28).reversed())
    }

    private var sleepGlancePoints: [SleepNightPoint] {
        if !hkSleepNights.isEmpty {
            let calendar = Calendar.current
            let cutoff = calendar.date(
                byAdding: .day, value: -28,
                to: calendar.startOfDay(for: .now)
            )!
            return hkSleepNights
                .filter { $0.wakeDay >= cutoff }
                .map { SleepNightPoint(date: $0.wakeDay, minutes: $0.tstMinutes) }
        }
        return sleepWindow.compactMap { snapshot in
            guard let minutes = snapshot.sleepDurationMinutes else { return nil }
            return SleepNightPoint(date: snapshot.date, minutes: minutes)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
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

                    // HRV + sleep glance charts, each navigating to its zoomed screen.
                    // Primitive 2 (Row): a well on press, no scale — surfaces that
                    // navigate, not keys that commit. The 16pt page margin is on the LINK,
                    // not its label, so the pressed well's rect is the card's rect.
                    RuledSection(header: "recovery.section.hrvTrend", topGap: Spacing.sm) {
                        NavigationLink(value: TrendDestination.hrv) {
                            HRVTrendChart(data: viewModel.hrvGlance)
                                // v6.3: HRV is the recovery area's primary reading, so this is
                                // the Trends hero — the one card here that takes the 4% wash.
                                // The sleep and load cards below stay plain stone.
                                .cardStyle(isHero: true)
                        }
                        .buttonStyle(.rowWell(cornerRadius: CornerTokens.card))
                        .padding(.horizontal, Spacing.sm)
                        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                        .accessibilityIdentifier("trends.hrvTrend")
                    }
                    .entranceReveal()

                    RuledSection(header: "recovery.section.sleepTrend") {
                        NavigationLink(value: TrendDestination.sleep) {
                            SleepTrendChart(nights: sleepGlancePoints)
                                .cardStyle()
                        }
                        .buttonStyle(.rowWell(cornerRadius: CornerTokens.card))
                        .padding(.horizontal, Spacing.sm)
                        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                    }
                    .entranceReveal(index: 1)

                    // Load trend (carried from the retired Load tab; range control Pro).
                    RuledSection(header: "workload.section.loadTrend") {
                        VStack(spacing: 0) {
                            if container.subscriptionService.isPro {
                                TimeRangeSegmentedControl(selected: $viewModel.selectedRange)
                                    .padding(.bottom, Spacing.sm)
                            }

                            if trendData.count > 1 {
                                LoadTrendChartView(
                                    snapshots: trendData,
                                    selectedDate: $selectedTrendDate
                                )
                                .cardStyle()
                            } else {
                                // Say why there is no chart (v1.7.2 / audit M10) — a young
                                // history, not a rendering failure.
                                Text("workload.chart.insufficientData")
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(Spacing.md)
                                    .cardStyle()
                            }
                        }
                        .padding(.horizontal, Spacing.sm)
                        .accessibilityIdentifier("trends.loadTrend")
                    }
                    // v6.3: a LOAD surface sitting on a recovery screen — the section owns the
                    // load hue, so its section rule reads as load while the rest of the screen
                    // reads as recovery. Ownership follows the metric, not the tab.
                    .metricArea(.load)
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
            .contentMargins(.top, Spacing.md, for: .scrollContent)
            .contentMargins(.bottom, Spacing.lg, for: .scrollContent)
            .background(ColorTokens.background)
            // v6.3 "The Area Tint": Trends is the RECOVERY area — its primary readings are HRV
            // and the recovery physiology behind the score. The load sections inside it declare
            // `.metricArea(.load)` on themselves (a section can own a different metric family
            // than the screen it sits on); the pushed detail screens declare their own.
            .metricArea(.recovery)
            .toolbar(.hidden, for: .navigationBar)
            // Same destination enum Home routes on, so both tabs land on the SAME
            // self-fetching screens (`TrendDetailScreens` — the one fetch path).
            .navigationDestination(for: TrendDestination.self) { destination in
                switch destination {
                case .hrv:   HRVDetailScreen()
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
                // `trendData` re-slices reactively from the query; the haptic marks the
                // commit and the animation settles the re-scaled chart.
                Haptics.select()
            }
        }
    }

    private func loadData() async {
        hkSleepNights = (try? await container.healthKitService.fetchSleepNights(days: 28)) ?? []
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
