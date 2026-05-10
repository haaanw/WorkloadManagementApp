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
    @State private var showQuickStartWorkout = false
    @State private var quickStartTemplate: WorkoutTemplate?
    @AppStorage("notificationPrePermissionShown") private var prePermissionShown: Bool = false

    private var athlete: Athlete? { athletes.first }

    private var showWelcomeCard: Bool {
        guard athlete != nil else { return false }
        return recentSessions.isEmpty && allCheckIns.isEmpty
    }

    private var showTrainingProfileCard: Bool {
        guard athlete != nil else { return false }
        return trainingProfiles.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    HeroReadinessCard(viewModel: viewModel)

                    QuickStartSection(
                        onSelectTemplate: { template in
                            quickStartTemplate = template
                            showQuickStartWorkout = true
                        }
                    )

                    if showWelcomeCard {
                        WelcomeActionCard(
                            onLogWorkout: { showActiveWorkout = true },
                            onWellnessCheckIn: { showWellnessCheckIn = true }
                        )
                    }

                    if showTrainingProfileCard {
                        TrainingProfileCard(onComplete: { showTrainingProfile = true })
                    }

                    if !viewModel.hasRealData {
                        EmptyStateCard {
                            Task { try? await container.healthKitService.requestAuthorization() }
                        }
                    }

                    Spacer().frame(height: 8)

                    MetricsStrip(viewModel: viewModel)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    Spacer().frame(height: 8)

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
                                            let body = NotificationService.buildNotificationBody(
                                                sessionCount: viewModel.weeklySummary?.sessionCount ?? 0,
                                                streak: viewModel.currentStreak,
                                                prCount: 0,
                                                volumeDelta: viewModel.weeklySummary?.volumeDelta ?? 0
                                            )
                                            container.notificationService.scheduleWeeklySummary(
                                                weekday: 1, hour: 19, minute: 0, body: body
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

                        Spacer().frame(height: 8)
                    } else if !viewModel.isLoading {
                        Text("Complete your first training week to see a summary.")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                        Spacer().frame(height: 8)
                    }

                    // Fatigue attention signal (D-FAT, COLD-07)
                    if viewModel.isColdStartActive {
                        // D-16: Show "Building baseline..." during cold-start
                        Text("Building baseline...")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .background(ColorTokens.surface)
                            .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
                        Spacer().frame(height: 8)
                    } else if let fi = viewModel.fatigueIndex, let zone = viewModel.fatigueZone,
                              zone != .low {
                        FatigueAttentionBanner(fatigueIndex: fi, zone: zone)
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                        Spacer().frame(height: 8)
                    }

                    TrainingLoadSection(viewModel: viewModel)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    Spacer().frame(height: 8)

                    RecentSessionsSection(sessions: Array(recentSessions.prefix(5)))
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(ColorTokens.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .withContextSwitcher()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Log Workout") {
                        showActiveWorkout = true
                    }
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                }
            }
            .sheet(isPresented: $showActiveWorkout) {
                ActiveWorkoutSheet()
            }
            .sheet(isPresented: $showQuickStartWorkout) {
                if let template = quickStartTemplate {
                    ActiveWorkoutSheet(template: template)
                        .environment(container)
                }
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
            syncService: container.syncService
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

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: .now).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("READINESS · \(dateLabel)")
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
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surface)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)
        }
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
                    .font(.system(size: 12, weight: .medium))
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
            Text("Connect Apple Health to see your readiness score.")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)

            Button(action: onConnectHealth) {
                Text("Connect Health")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .overlay(
                        Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)
        }
    }
}

// MARK: - Metrics Strip

struct MetricsStrip: View {
    let viewModel: DashboardViewModel

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
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
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
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}

// MARK: - Training Load Section

struct TrainingLoadSection: View {
    let viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("TRAINING LOAD")
                    .font(.Tokens.micro)
                    .tracking(1.2)
                    .foregroundStyle(ColorTokens.text3)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
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
                Text("EST")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RECENT SESSIONS")
                .font(.Tokens.micro)
                .tracking(1.2)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)

            if sessions.isEmpty {
                Text("No sessions yet. Tap Log Workout to begin.")
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
                                Text(session.sessionDate.relativeString)
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text2)
                            }
                            Spacer()
                            if let rpe = session.sessionRPE {
                                Text("RPE \(Int(rpe))")
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

// MARK: - Quick Start Section

struct QuickStartSection: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]

    let onSelectTemplate: (WorkoutTemplate) -> Void

    @State private var suggestionResult: TemplateSuggestionEngine.SuggestionResult?

    private var quickStartTemplates: [WorkoutTemplate] {
        guard let athleteId = athletes.first?.id else { return [] }
        let repo = TemplateRepository(modelContext: modelContext)
        let favorites = (try? repo.fetchFavorites(athleteId: athleteId)) ?? []

        var result: [WorkoutTemplate]
        if favorites.isEmpty {
            // Fallback: show most recently used templates when none are favorited
            let all = (try? repo.fetchAthleteTemplates(athleteId: athleteId)) ?? []
            result = Array(all.prefix(3))
        } else {
            result = Array(favorites.prefix(3))
        }

        // Add suggestion if Pro and not already in favorites
        if container.subscriptionService.isPro,
           let suggestion = suggestionResult,
           !result.contains(where: { $0.id == suggestion.template.id }) {
            result.append(suggestion.template)
        }

        return Array(result.prefix(4))
    }

    var body: some View {
        let templates = quickStartTemplates
        if !templates.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Quick Start")
                    .font(.Tokens.bodyMedium)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(templates, id: \.id) { template in
                            quickStartCard(template)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }
            .background(ColorTokens.background)
            .overlay(alignment: .bottom) {
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            }
            .onAppear { computeSuggestion() }
        }
    }

    private func quickStartCard(_ template: WorkoutTemplate) -> some View {
        let isSuggested = container.subscriptionService.isPro
            && suggestionResult?.template.id == template.id

        return Button {
            onSelectTemplate(template)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: template.sportType.systemImage)
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.text2)
                    Spacer()
                    if isSuggested {
                        Text("SUGGESTED")
                            .font(.Tokens.micro)
                            .tracking(1.2)
                            .textCase(.uppercase)
                            .foregroundStyle(ColorTokens.text2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .overlay(
                                Rectangle().stroke(ColorTokens.zoneOptimal, lineWidth: 0.5)
                            )
                    }
                }

                Text(template.templateName)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 140, alignment: .leading)
            .padding(16)
            .background(ColorTokens.surface)
            .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quick start \(template.templateName)")
    }

    private func computeSuggestion() {
        guard container.subscriptionService.isPro else { return }
        guard let athleteId = athletes.first?.id else { return }
        let allTemplates = (try? TemplateRepository(modelContext: modelContext)
            .fetchAthleteTemplates(athleteId: athleteId)) ?? []
        guard !allTemplates.isEmpty else { return }

        let fourWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: .now)!
        let sessionDescriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.sessionDate >= fourWeeksAgo },
            sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
        )
        let sessions = (try? modelContext.fetch(sessionDescriptor)) ?? []

        var recoveryDescriptor = FetchDescriptor<RecoverySnapshot>(
            sortBy: [SortDescriptor<RecoverySnapshot>(\.date, order: .reverse)]
        )
        recoveryDescriptor.fetchLimit = 1
        let latestRecovery = (try? modelContext.fetch(recoveryDescriptor))?.first
        let recoveryZone = latestRecovery.map { RecoveryZone.classify(score: $0.recoveryScore) } ?? .green

        suggestionResult = TemplateSuggestionEngine.suggest(
            templates: allTemplates,
            recentSessions: sessions,
            currentRecoveryZone: recoveryZone
        )
    }
}
