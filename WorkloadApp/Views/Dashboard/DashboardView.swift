import SwiftUI
import SwiftData

enum TrendDestination: Hashable {
    case hrv
    case sleep
}

struct DashboardView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var athletes: [Athlete]
    @Query(sort: \WorkoutSession.sessionDate, order: .reverse)
    private var recentSessions: [WorkoutSession]
    @Query private var allCheckIns: [WellnessCheckIn]
    @Query private var trainingProfiles: [TrainingProfile]
    @State private var showActiveWorkout = false
    @State private var showWellnessCheckIn = false
    @State private var showTrainingProfile = false
    @State private var viewModel = DashboardViewModel()
    @AppStorage("notificationPrePermissionShown") private var prePermissionShown: Bool = false
    @AppStorage("cyclePromptDismissed") private var cyclePromptDismissed: Bool = false
    @Query private var cycleSnapshots: [MenstrualCycleSnapshot]

    private var athlete: Athlete? { athletes.first }

    private var showWelcomeCard: Bool {
        guard athlete != nil else { return false }
        return recentSessions.isEmpty && allCheckIns.isEmpty
    }

    private var showTrainingProfileCard: Bool {
        guard athlete != nil else { return false }
        return trainingProfiles.isEmpty
    }

    private var showCyclePrompt: Bool {
        !cyclePromptDismissed && cycleSnapshots.isEmpty
    }

    /// Latest cycle snapshot (D-02). Nil when no HealthKit menstrual data exists (SC6 — UI invisible).
    private var latestCycleSnapshot: MenstrualCycleSnapshot? {
        cycleSnapshots.sorted { $0.date > $1.date }.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    HeroReadinessCard(viewModel: viewModel)

                    if showWelcomeCard {
                        WelcomeActionCard(
                            onLogWorkout: { showActiveWorkout = true },
                            onWellnessCheckIn: { showWellnessCheckIn = true }
                        )
                    }

                    if showTrainingProfileCard {
                        TrainingProfileCard(onComplete: { showTrainingProfile = true })
                    }

                    // HealthKit empty-state routing:
                    //  - .notRequested → connect CTA
                    //  - .requestedNoData → benign "connected, no recent data" (NOT the connect CTA)
                    //  - .connected → nothing (normal data view)
                    //
                    // Read the LIVE connectionState from the @Observable HealthKitService (not a
                    // stale copy snapshotted in viewModel.load()). HealthKitService is @MainActor
                    // @Observable, so reading connectionState here registers an Observation
                    // dependency on its `hasRequestedAccess` / `hasObservedData` stored properties.
                    // When the detached migration probe (AppRouter) or a Connect tap flips either
                    // flag, SwiftUI re-renders this view body immediately — no reload required.
                    if !viewModel.hasRealData {
                        switch container.healthKitService.connectionState {
                        case .notRequested:
                            EmptyStateCard {
                                Task { try? await container.healthKitService.requestAuthorization() }
                            }
                        case .requestedNoData:
                            HealthKitNoDataCard()
                        case .connected:
                            EmptyView()
                        }
                    }

                    // Cycle-aware recovery soft prompt (D-02)
                    if showCyclePrompt {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("dashboard.cycleAware.title")
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Spacer()
                                Button {
                                    cyclePromptDismissed = true
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.Tokens.smallLabel)
                                        .foregroundStyle(ColorTokens.text2)
                                }
                                .accessibilityLabel("Dismiss cycle tracking prompt")
                            }
                            Text("dashboard.cycleAware.body")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("action.openSettings")
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text1)
                                    .underline()
                            }
                        }
                        .cardStyle(verticalPadding: Spacing.sm)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.top, Spacing.xs)
                    }

                    // Unobtrusive opt-in cycle indicator (CYCLE-06 SC1, D-07).
                    // Invisible when no HealthKit menstrual data (latestCycleSnapshot == nil, SC6/D-01).
                    if let snap = latestCycleSnapshot {
                        CycleStatusStrip(snapshot: snap)
                        Spacer().frame(height: Spacing.xs)
                    }

                    MetricsStrip(viewModel: viewModel)

                    Spacer().frame(height: Spacing.lg)

                    // Weekly Summary (ANLYT-02, ANLYT-03, D-03)
                    if let summary = viewModel.weeklySummary, summary.sessionCount > 0 {
                        WeeklySummaryCard(summary: summary, streak: viewModel.currentStreak)
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                        // Notification pre-permission card (NOTF-02, D-07)
                        if !prePermissionShown {
                            NotificationPrePermissionCard(
                                onEnable: {
                                    prePermissionShown = true
                                    Task {
                                        let granted = await container.notificationService.requestAuthorization()
                                        if granted {
                                            container.notificationService.scheduleWeeklySummary(
                                                weekday: 1,
                                                hour: 19,
                                                minute: 0,
                                                sessionCount: viewModel.weeklySummary?.sessionCount ?? 0,
                                                streak: viewModel.currentStreak,
                                                prCount: 0,
                                                volumeDelta: viewModel.weeklySummary?.volumeDelta ?? 0
                                            )
                                            UserDefaults.standard.set(true, forKey: "notificationsEnabled")
                                            UserDefaults.standard.set(1, forKey: "notificationDay")
                                            UserDefaults.standard.set("19:00", forKey: "notificationTime")
                                        }
                                    }
                                },
                                onDismiss: {
                                    prePermissionShown = true
                                }
                            )
                            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                        }

                        Spacer().frame(height: Spacing.lg)
                    } else if !viewModel.isLoading {
                        Text("dashboard.weeklySummary.firstWeekPrompt")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .cardStyle(verticalPadding: Spacing.sm)
                        Spacer().frame(height: Spacing.lg)
                    }

                    // Fatigue attention signal (D-FAT, COLD-07)
                    if viewModel.isColdStartActive {
                        // D-16: Show "Building baseline..." during cold-start
                        Text("dashboard.coldStart.buildingBaseline")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .cardStyle(verticalPadding: Spacing.sm)
                        Spacer().frame(height: Spacing.lg)
                    } else if let fi = viewModel.fatigueIndex, let zone = viewModel.fatigueZone,
                              zone != .low {
                        FatigueAttentionBanner(fatigueIndex: fi, zone: zone)
                        Spacer().frame(height: Spacing.lg)
                    }

                    TrainingLoadSection(viewModel: viewModel)

                    Spacer().frame(height: Spacing.lg)

                    RecentSessionsSection(sessions: Array(recentSessions.prefix(5)))
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("dashboard.nav.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ColorTokens.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .withContextSwitcher()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("dashboard.action.logWorkout") {
                        showActiveWorkout = true
                    }
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                }
            }
            .sheet(isPresented: $showActiveWorkout) {
                ActiveWorkoutSheet()
            }
            .sheet(isPresented: $showWellnessCheckIn) {
                MorningCheckInSheet()
            }
            .sheet(isPresented: $showTrainingProfile) {
                TrainingProfileSheet()
            }
            .navigationDestination(for: TrendDestination.self) { dest in
                switch dest {
                case .hrv:   HRVDetailView(data: viewModel.hrv28Days)
                case .sleep: SleepDetailView(snapshots: viewModel.recentSnapshots)
                }
            }
            .task {
                await loadData()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await loadData() }
                }
            }
        }
    }

    private func loadData() async {
        guard let athlete else { return }
        await viewModel.load(
            athlete: athlete,
            healthKitService: container.healthKitService,
            modelContext: modelContext,
            syncService: container.syncService,
            cycleTrackingService: container.cycleTrackingService
        )
        // Refresh notification content with current data (NOTF-01 staleness prevention)
        viewModel.refreshNotificationContent(
            notificationService: container.notificationService,
            modelContext: modelContext
        )
    }
}

// MARK: - Hero Readiness Card

struct HeroReadinessCard: View {
    let viewModel: DashboardViewModel
    @Environment(\.locale) private var locale

    private var dateLabel: String {
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("EEEdMMM")
        let s = f.string(from: .now)
        return locale.language.languageCode?.identifier == "en" ? s.uppercased() : s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(format: String(localized: "dashboard.hero.readinessLabel"), dateLabel))
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)

            if viewModel.hasRealData {
                Text("\(Int(viewModel.recoveryScore))")
                    .font(.Tokens.heroScore)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.accent)
            }

            // Periodization phase label (D-01, D-02)
            if let phaseLabel = viewModel.trainingPhaseLabel {
                Text(phaseLabel)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            } else if let sufficiency = viewModel.periodizationSufficiency,
                      !sufficiency.isSufficient,
                      sufficiency.weeksAvailable > 0 {
                DataSufficiencyRing(
                    progress: Double(sufficiency.weeksAvailable) / Double(sufficiency.weeksRequired),
                    label: "\(sufficiency.weeksAvailable) of \(sufficiency.weeksRequired) weeks",
                    message: "Keep logging -- periodization insights unlock after \(sufficiency.weeksRequired) weeks of consistent training"
                )
            }

            if viewModel.hasRealData && !viewModel.reasoningFactors.isEmpty {
                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(viewModel.reasoningFactors.prefix(2).enumerated()), id: \.offset) { _, factor in
                        factorRow(factor)
                    }
                }

                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
            }

            if let rec = viewModel.recommendation {
                Text(rec.headline)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private func factorRow(_ factor: ReasoningEngine.Factor) -> some View {
        let content = HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(factor.label)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                Text(factor.deltaText)
                    .font(.Tokens.label)
                    .foregroundStyle(factorColor(factor.direction))
            }
            Spacer()
            if trendDestination(for: factor) != nil {
                Image(systemName: "chevron.right")
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text3)
            }
        }

        if let dest = trendDestination(for: factor) {
            NavigationLink(value: dest) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func trendDestination(for factor: ReasoningEngine.Factor) -> TrendDestination? {
        switch factor.label {
        case "Heart Rate Variability": return .hrv
        case "Sleep Duration":         return .sleep
        default:                       return nil
        }
    }

    private func factorColor(_ direction: ReasoningEngine.Factor.Direction) -> Color {
        switch direction {
        case .positive: ColorTokens.zoneOptimal
        case .negative: ColorTokens.zoneDanger
        case .neutral:  ColorTokens.text2
        }
    }
}

// MARK: - Empty State (no HealthKit data)

struct EmptyStateCard: View {
    let onConnectHealth: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("dashboard.empty.connectHealth")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)

            Button(action: onConnectHealth) {
                Text("dashboard.action.connectHealth")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .overlay(
                        Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
                    )
            }
        }
        .cardStyle()
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.xs)
    }
}

/// Shown when the user has connected Apple Health but no recent samples are visible yet.
/// This is a benign informational state — NOT the connect CTA and NOT an error.
struct HealthKitNoDataCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("dashboard.healthkit.noRecentData")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)
        }
        .cardStyle()
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.xs)
    }
}

// MARK: - Metrics Strip

struct MetricsStrip: View {
    let viewModel: DashboardViewModel
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 0) {
            MetricStripCell(
                label: "HRV",
                value: viewModel.latestHRV.map { String(format: "%.0f", $0) } ?? "—",
                unit: viewModel.latestHRV != nil ? "ms" : nil,
                staleDaysAgo: viewModel.staleness.daysAgo(viewModel.staleness.lastHRVDate)
            )
            Rectangle().fill(ColorTokens.divider).frame(width: 0.5)

            MetricStripCell(
                label: "RHR",
                value: viewModel.latestRHR.map { String(format: "%.0f", $0) } ?? "—",
                unit: viewModel.latestRHR != nil ? "bpm" : nil,
                staleDaysAgo: viewModel.staleness.daysAgo(viewModel.staleness.lastRHRDate)
            )
            Rectangle().fill(ColorTokens.divider).frame(width: 0.5)

            MetricStripCell(
                label: "SLEEP",
                value: viewModel.latestSleepMinutes.map { sleepString($0) } ?? "—",
                unit: nil,
                staleDaysAgo: viewModel.staleness.daysAgo(viewModel.staleness.lastSleepDate)
            )
        }
        .frame(maxWidth: .infinity)
        .background(ColorTokens.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)
        }
    }

    private func sleepString(_ minutes: Double) -> String {
        Date.durationString(seconds: Int(minutes) * 60, locale: locale)
    }
}

struct MetricStripCell: View {
    let label: String
    let value: String
    let unit: String?
    var staleDaysAgo: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.Tokens.sectionHead)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.text1)
                if let unit {
                    Text(unit)
                        .font(.Tokens.micro)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
            if let days = staleDaysAgo {
                StalenessWarningBadge(daysAgo: days)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Training Load Section

struct TrainingLoadSection: View {
    let viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("dashboard.section.trainingLoad")
                    .font(.Tokens.sectionHead)
                    .foregroundStyle(ColorTokens.text1)
                Spacer()
                ZoneBadge(
                    label: viewModel.acwrZone.displayName,
                    color: ColorTokens.acwrZoneColor(viewModel.acwrZone)
                )
            }

            if viewModel.acwrZone != .noData {
                GeometryReader { geo in
                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 1)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(ColorTokens.acwrZoneColor(viewModel.acwrZone))
                                .frame(width: geo.size.width * min(viewModel.acwr / 2.0, 1.0), height: 1)
                        }
                }
                .frame(height: 1)
            }

            HStack(spacing: 24) {
                LoadStatCell(
                    label: "ACWR",
                    value: viewModel.acwrZone == .noData && !viewModel.isColdStartActive ? "---" : String(format: "%.2f", viewModel.acwr),
                    isEstimated: viewModel.isColdStartActive
                )
                LoadStatCell(
                    label: "ATL",
                    value: viewModel.acwrZone == .noData && !viewModel.isColdStartActive ? "---" : String(format: "%.0f", viewModel.atl),
                    isEstimated: viewModel.isColdStartActive
                )
                LoadStatCell(
                    label: "CTL",
                    value: viewModel.acwrZone == .noData && !viewModel.isColdStartActive ? "---" : String(format: "%.0f", viewModel.ctl),
                    isEstimated: viewModel.isColdStartActive
                )
                LoadStatCell(
                    label: "TSB",
                    value: viewModel.acwrZone == .noData && !viewModel.isColdStartActive ? "---" : String(format: "%+.0f", viewModel.tsb),
                    isEstimated: viewModel.isColdStartActive
                )
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.md)
        .background(ColorTokens.background)
    }
}

struct LoadStatCell: View {
    let label: String
    let value: String
    var isEstimated: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
            Text(value)
                .font(.Tokens.label)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
            if isEstimated {
                Text("dashboard.label.estimated")
                    .font(.Tokens.micro)
                    .tracking(0.88)
                    .foregroundStyle(ColorTokens.text3)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isEstimated ? "\(label) \(value), estimated" : "\(label) \(value)")
    }
}

// MARK: - Recent Sessions Section

struct RecentSessionsSection: View {
    let sessions: [WorkoutSession]
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "dashboard.section.recentSessions")
                .padding(.bottom, Spacing.sm)

            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)

            if sessions.isEmpty {
                Text("dashboard.empty.noSessions")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
            } else {
                ForEach(sessions, id: \.id) { session in
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.sessionName ?? session.sportType.displayName)
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Text(session.sessionDate.relativeString(locale: locale))
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text2)
                            }
                            Spacer()
                            if let rpe = session.sessionRPE {
                                Text(String(format: String(localized: "dashboard.session.rpeValue"), Int(rpe)))
                                    .font(.Tokens.label)
                                    .monospacedDigit()
                                    .foregroundStyle(ColorTokens.text2)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)

                        Rectangle()
                            .fill(ColorTokens.divider)
                            .frame(height: 0.5)
                    }
                }
            }
        }
        .background(ColorTokens.background)
    }
}

