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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    // 0. Editorial screen header (Stage 4a) — the visible title lives in the
                    //    content, not the stock nav bar; the log action rides its baseline.
                    ScreenHeader(title: "dashboard.nav.title") {
                        // Inherits the header-action slot styling (10pt Medium micro-caps,
                        // text2) from ScreenHeader — no per-site font/color overrides.
                        Button("dashboard.action.logWorkout") {
                            Haptics.tap()
                            showActiveWorkout = true
                        }
                        .buttonStyle(.pressable)
                    }

                    // 1. Hero readiness — score + recommendation headline in its footer (recommendation stays "up top").
                    HeroReadinessCard(viewModel: viewModel)
                        .accessibilityIdentifier("dashboard.hero")
                        .padding(.horizontal, Spacing.sm)
                        .entranceReveal()

                    // 2. Phase 28 Wave 4 — FLAGGED dual-run card; placement PROVISIONAL, flagged for human visual review.
                    // Flag OFF (default) → dualRunMessage nil → PRSDualRunCard renders EmptyView → layout byte-identical.
                    // UNTOUCHED — flag-gated exactly as before.
                    PRSDualRunCard(message: viewModel.dualRunMessage)

                    // 3. Recommendation-aware primary action — always presents ActiveWorkoutSheet (logging never blocked).
                    PrimaryActionCTA(
                        recommendation: viewModel.recommendation,
                        onTap: { showActiveWorkout = true }
                    )

                    // 4. Established-user value cluster (C.2): once the user has real data, prioritise
                    //    "what's my load + what do I do + act" — fatigue/cold-start → load → metrics →
                    //    weekly summary → recent sessions — directly under the hero/CTA. Setup/connect
                    //    prompts are demoted below (group 5). Their own render guards already hide them
                    //    once established, so cold-start users (hasRealData == false) instead see the
                    //    setup prompts near the top (group 5 renders first because this cluster is empty).
                    // The load/baseline cluster (fatigue/cold-start signal + TrainingLoadSection)
                    // must surface for cold-start users too (isColdStartActive == true while
                    // hasRealData == false) — phase-40's reorder had wrapped it in
                    // `if hasRealData`, hiding the estimated ATL/CTL/ACWR (isEstimated) surface
                    // during cold-start. TrainingLoadSection renders exactly once here for both
                    // cold-start and established users; the established-only sections (metrics,
                    // weekly summary, recent sessions) stay gated on hasRealData below.
                    if viewModel.hasRealData || viewModel.isColdStartActive {
                        Spacer().frame(height: Spacing.lg)

                        // Fatigue attention signal (D-FAT, COLD-07)
                        if viewModel.isColdStartActive {
                            // D-16: Show "Building baseline..." during cold-start
                            Text("dashboard.coldStart.buildingBaseline")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                                .cardStyle(verticalPadding: Spacing.sm)
                                .padding(.horizontal, Spacing.sm)
                            Spacer().frame(height: Spacing.lg)
                        } else if let fi = viewModel.fatigueIndex, let zone = viewModel.fatigueZone,
                                  zone != .low {
                            FatigueAttentionBanner(fatigueIndex: fi, zone: zone)
                                .padding(.horizontal, Spacing.sm)
                            Spacer().frame(height: Spacing.lg)
                        }

                        TrainingLoadSection(viewModel: viewModel)
                            .padding(.horizontal, Spacing.sm)
                            .entranceReveal(index: 1)

                        Spacer().frame(height: Spacing.lg)
                    } else if viewModel.isLoading && !viewModel.hasLoadedOnce {
                        // First-load skeleton where the training-load card will land — a calm
                        // plate-shaped placeholder so the section arrives as a transition.
                        Spacer().frame(height: Spacing.lg)
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            SkeletonBlock(width: 96, height: 16)
                            SkeletonBlock(height: 48)
                        }
                        .cardStyle()
                        .padding(.horizontal, Spacing.sm)
                        .transition(.opacity)

                        Spacer().frame(height: Spacing.lg)
                    }

                    // Established-user value cluster (metrics → weekly summary → recent sessions)
                    // remains hasRealData-only: these surfaces require real data and are NOT shown
                    // during cold-start.
                    if viewModel.hasRealData {
                        MetricsStrip(viewModel: viewModel)
                            .padding(.horizontal, Spacing.sm)
                            .entranceReveal(index: 2)

                        Spacer().frame(height: Spacing.lg)

                        // Weekly Summary (ANLYT-02, ANLYT-03, D-03)
                        if let summary = viewModel.weeklySummary, summary.sessionCount > 0 {
                            WeeklySummaryCard(summary: summary, streak: viewModel.currentStreak)
                                .padding(.horizontal, Spacing.sm)
                            // Bordered card planes separate by grid gap, not a jammed hairline
                            // (hairlines are for rows INSIDE a plane — Separator Grammar).
                            Spacer().frame(height: Spacing.sm)

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
                                .padding(.horizontal, Spacing.sm)
                            }

                            Spacer().frame(height: Spacing.lg)
                        } else if !viewModel.isLoading {
                            Text("dashboard.weeklySummary.firstWeekPrompt")
                                .font(.Tokens.label)
                                .foregroundStyle(ColorTokens.text2)
                                .cardStyle(verticalPadding: Spacing.sm)
                                .padding(.horizontal, Spacing.sm)
                            Spacer().frame(height: Spacing.lg)
                        }

                        RecentSessionsSection(sessions: Array(recentSessions.prefix(5)))
                            .padding(.horizontal, Spacing.sm)
                            .entranceReveal(index: 3)

                        Spacer().frame(height: Spacing.lg)
                    }

                    // 5. Setup / connect prompt group — guards UNCHANGED. For cold-start users
                    //    (hasRealData == false) these are the first content under the CTA (prominent);
                    //    for established users their guards no-op so nothing extra renders here.
                    if showWelcomeCard {
                        WelcomeActionCard(
                            onLogWorkout: { showActiveWorkout = true },
                            onWellnessCheckIn: { showWellnessCheckIn = true }
                        )
                        .padding(.horizontal, Spacing.sm)
                    }

                    if showTrainingProfileCard {
                        SectionContainer {
                            TrainingProfileCard(onComplete: { showTrainingProfile = true })
                                .padding(.horizontal, Spacing.sm)
                        }
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
                            .transition(.opacity)
                        case .requestedNoData:
                            HealthKitNoDataCard()
                                .transition(.opacity)
                        case .connected:
                            EmptyView()
                        }
                    }

                    Spacer().frame(height: Spacing.lg)
                }
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: viewModel.hasRealData)
                .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: viewModel.isLoading)
            }
            // Editorial rhythm (Stage 3): generous breathing room under the status bar
            // before the header. Stage 4a: the stock nav bar is hidden on this root — the
            // title is the in-content ScreenHeader; pushed detail screens keep their own
            // nav bars (and back buttons) untouched.
            .contentMargins(.top, Spacing.md, for: .scrollContent)
            .contentMargins(.bottom, Spacing.lg, for: .scrollContent)
            .background(ColorTokens.background)
            .toolbar(.hidden, for: .navigationBar)
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
                case .hrv:   HRVDetailView(data: viewModel.hrv90Days, rawSampleCount: viewModel.hrvRawSampleCount)
                case .sleep: SleepDetailView(snapshots: viewModel.recentSnapshots90)
                }
            }
            .task {
                await loadData()
            }
            .onAppear { Haptics.prepare() }
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
        // ACT-01 — explicit PRODUCTION opt-in: activate the verdict-feeding dashboard surface so the
        // live PRS readiness/strain pipeline runs (no longer tests-only). Synchronous, AFTER the async
        // load returns, so VerdictSurfaceActivation.withEnabled(true) fully wraps the sync build with
        // no await straddle. Cold-start/low-confidence still defers (builder returns nil).
        viewModel.activateVerdictSurface()
        // Refresh notification content with current data (NOTF-01 staleness prevention)
        viewModel.refreshNotificationContent(
            notificationService: container.notificationService,
            modelContext: modelContext
        )
    }
}

// MARK: - Primary Action CTA

/// Recommendation-aware primary-action button shown directly under the hero readiness score.
/// Label adapts to the existing AutoregulationEngine recommendation (no new engine/VM logic);
/// the action ALWAYS presents ActiveWorkoutSheet — logging is never blocked regardless of label.
/// DESIGN.md v5 "Pavilion" CTA Law: the primary CTA is the shared ink-filled pill
/// (`PrimaryActionButton`) — the one per screen, never accent-filled (Accent Rule).
struct PrimaryActionCTA: View {
    let recommendation: AutoregulationEngine.TrainingRecommendation?
    let onTap: () -> Void

    private var labelKey: LocalizedStringKey {
        switch recommendation?.sessionType {
        case .rest:
            return "dashboard.cta.logRestDay"
        case .activeRecovery:
            return "dashboard.cta.logLightSession"
        case .power, .strength, .hypertrophy, .conditioning:
            return "dashboard.cta.startSession"
        case nil:
            return "dashboard.cta.logWorkout"
        }
    }

    var body: some View {
        // v5 CTA Law: the primary CTA is the shared INK-FILLED pill (accent never fills a
        // CTA). Haptics + press treatment come with the shared button.
        PrimaryActionButton(title: labelKey, action: onTap)
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.lg)
    }
}

// MARK: - Hero Readiness Card

struct HeroReadinessCard: View {
    let viewModel: DashboardViewModel
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Drives the signature hero count-up: animates 0 → recoveryScore on appear via Motion.scoreCountUp.
    @State private var displayedScore: Double = 0

    private var dateLabel: String {
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate("EEEdMMM")
        let s = f.string(from: .now)
        return locale.language.languageCode?.identifier == "en" ? s.uppercased() : s
    }

    /// The score band of the CURRENT recovery zone (RecoveryZone.classify thresholds) —
    /// rendered as the TickScale ink zone band (the accent needle marks the reading).
    private var zoneBand: ClosedRange<Double> {
        switch viewModel.recoveryZone {
        case .red:    return 0...34
        case .yellow: return 34...66
        case .green:  return 66...100
        }
    }

    var body: some View {
        // Hero Law (v5, recolored by v6): the readiness reading lives on THE one raised light
        // hero card on Home — an ANNOTATION stamp ("READINESS · TUE 21 JUL") in the readiness
        // hue, the 64pt `heroScore` reading in `metricReadiness` (Reading Color Rule v6: the
        // hero takes its metric's hue; travertine keeps live-state marks), zone as a TEXT label
        // in its zone color, and a full-width TickScale 0–100 with the ink zone band and the
        // accent needle at the score. Supporting matter (reason tree, periodization,
        // recommendation) stays demoted onto a quiet card below.
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // The screen's context stamp is marginalia, not speech — mono, uppercase,
                // tracked, tabular, CJK-guarded, all inside `AnnotationLabel`. Carries the
                // readiness hue because it keys the reading beneath it (DESIGN.md v6 Reading
                // Color Rule, metric-hue annotation); legal below 24pt because the raised hero
                // is a CARD plane (4.71:1).
                AnnotationLabel(
                    String(format: String(localized: "dashboard.hero.readinessLabel"), dateLabel),
                    color: ColorTokens.metricReadiness
                )
                    .annotationReveal()
                    .animation(Motion.resolved(Motion.screen, reduceMotion: reduceMotion), value: viewModel.hasRealData)

                Spacer().frame(height: Spacing.sm)

                if viewModel.isLoading && !viewModel.hasLoadedOnce {
                    // Calm first-load placeholder where the score will land — data arrival is a
                    // cross-fade (the parent animates on isLoading), not a pop. No shimmer.
                    SkeletonBlock(width: 144, height: 88)
                        .transition(.opacity)
                } else if viewModel.hasRealData {
                    // Baseline-aligned readout: the hero reading dominates the left, the
                    // zone label is pinned to the trailing edge on the score's baseline —
                    // tension across the card instead of a label tucked beside it.
                    HStack(alignment: .lastTextBaseline, spacing: Spacing.sm) {
                        Text("\(Int(displayedScore))")
                            .font(.Tokens.heroScore)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            // Reading Color Rule v6: the hero reading is THE one colored text
                            // element and takes ITS OWN metric's hue — readiness is verdant
                            // green. (v5 gave this to travertine; travertine now owns
                            // live-state marks exclusively, e.g. the TickScale needle below.)
                            .foregroundStyle(ColorTokens.metricReadiness)
                        Spacer(minLength: Spacing.sm)
                        // Zone state text-first, in its zone color (never color alone —
                        // the label carries the meaning; the color is supplementary).
                        Text(viewModel.recoveryZone.displayName)
                            .font(.Tokens.micro)
                            .tracking(0.9)
                            .textCase(.uppercase)
                            .foregroundStyle(ColorTokens.recoveryZoneColor(viewModel.recoveryZone))
                    }
                    .transition(.opacity)
                    .onAppear {
                        updateDisplayedScore(to: viewModel.recoveryScore)
                    }
                    .onChange(of: viewModel.recoveryScore) { _, newValue in
                        updateDisplayedScore(to: newValue)
                    }

                    Spacer().frame(height: Spacing.sm)

                    TickScale(
                        range: 0...100,
                        value: displayedScore,
                        zone: zoneBand,
                        variant: .scale,
                        theme: .light,
                        detents: true,
                        accessibilityLabel: Text(verbatim: "\(Int(viewModel.recoveryScore)) / 100 · \(viewModel.recoveryZone.displayName)")
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .raised(cornerRadius: CornerTokens.card)

            if hasSupportingContent {
                Spacer().frame(height: Spacing.xs)
                supportingCard
            }
        }
    }

    /// Whether the light supporting card under the hero card has anything to show —
    /// avoids rendering an empty card plane during cold start.
    private var hasSupportingContent: Bool {
        if viewModel.hasRealData && !viewModel.reasoningFactors.isEmpty { return true }
        if viewModel.trainingPhaseLabel != nil { return true }
        if let sufficiency = viewModel.periodizationSufficiency,
           !sufficiency.isSufficient,
           sufficiency.weeksAvailable > 0 { return true }
        if viewModel.recommendation != nil { return true }
        return false
    }

    /// Supporting matter — metric factor rows (tabular readings), periodization,
    /// recommendation headline — on a quiet light card under the hero card.
    private var supportingCard: some View {
        VStack(alignment: .leading, spacing: 0) {
                if viewModel.hasRealData && !viewModel.reasoningFactors.isEmpty {
                    let factors = Array(viewModel.reasoningFactors.prefix(2))
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        ForEach(Array(factors.enumerated()), id: \.offset) { index, factor in
                            factorRow(factor, index: index, isLast: index == factors.count - 1)
                        }
                    }

                    Spacer().frame(height: Spacing.sm)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    Spacer().frame(height: Spacing.sm)
                }

                // Periodization phase label (D-01, D-02) — compact single supporting row.
                if let phaseLabel = viewModel.trainingPhaseLabel {
                    Text(phaseLabel)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                    Spacer().frame(height: Spacing.sm)
                } else if let sufficiency = viewModel.periodizationSufficiency,
                          !sufficiency.isSufficient,
                          sufficiency.weeksAvailable > 0 {
                    DataSufficiencyRing(
                        progress: Double(sufficiency.weeksAvailable) / Double(sufficiency.weeksRequired),
                        label: String(localized: "dashboard.periodization.progress", defaultValue: "\(sufficiency.weeksAvailable) of \(sufficiency.weeksRequired) weeks"),
                        message: String(localized: "dashboard.periodization.unlock", defaultValue: "Keep logging — periodization insights unlock after \(sufficiency.weeksRequired) weeks of consistent training")
                    )
                    Spacer().frame(height: Spacing.sm)
                }

                if let rec = viewModel.recommendation {
                    Text(rec.headline)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                }
        }
        .cardStyle(verticalPadding: Spacing.sm)
    }

    private func updateDisplayedScore(to score: Double) {
        guard !reduceMotion else {
            displayedScore = score
            return
        }
        withAnimation(Motion.scoreCountUp) {
            displayedScore = score
        }
    }

    /// One branch of the readiness reason tree. The factor NAME stays in the working voice (it
    /// is a label the app says, and the row navigates); its measured delta is **marginalia** —
    /// mono, uppercase, box-drawing-prefixed (`├─` / `└─`), so the two rows read as the
    /// verdict's why (DESIGN.md v6 annotation layer + glyph set). The direction color is legal
    /// below 24pt because the supporting card is a CARD plane.
    @ViewBuilder
    private func factorRow(_ factor: ReasoningEngine.Factor, index: Int, isLast: Bool) -> some View {
        let content = HStack(spacing: 0) {
            // Tight label→value pairing (baselinePair) — supporting rows stay compact under the score.
            VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                Text(factor.label)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                AnnotationLabel(
                    "\(isLast ? "└─" : "├─") \(factor.deltaText)",
                    color: factorColor(factor.direction)
                )
                    .annotationReveal(index: index)
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
                .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: "waveform.path.ecg")
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text2)
                .accessibilityHidden(true)

            Text("dashboard.empty.connectHealth")
                .font(.Tokens.body)
                .foregroundStyle(ColorTokens.text2)

            Button {
                Haptics.tap()
                onConnectHealth()
            } label: {
                // v5: secondary action is a quiet hairline-bordered rectangular key
                // (control corners) — the pill is reserved for the one primary CTA, and
                // accent never marks a CTA.
                Text("dashboard.action.connectHealth")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerTokens.control)
                            .stroke(ColorTokens.dividerStrong, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.pressable)
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
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: "heart.text.square")
                .font(.Tokens.pageTitle)
                .foregroundStyle(ColorTokens.text2)
                .accessibilityHidden(true)

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
        // Demo §3 After: RHR/HRV/Sleep as a 3-cell metric grid — individually-planed cells
        // with unit superscripts, scannable in one fixation instead of a butted strip. Each
        // cell keeps its staleness badge in the bottom accessory slot (no behaviour change).
        HStack(alignment: .top, spacing: Spacing.xs) {
            MetricCell(
                label: "HRV",
                value: viewModel.latestHRV.map { String(format: "%.0f", $0) } ?? "—",
                unit: viewModel.latestHRV != nil ? "ms" : nil
            ) { staleAccessory(viewModel.staleness.daysAgo(viewModel.staleness.lastHRVDate)) }

            MetricCell(
                label: "RHR",
                value: viewModel.latestRHR.map { String(format: "%.0f", $0) } ?? "—",
                unit: viewModel.latestRHR != nil ? "bpm" : nil
            ) { staleAccessory(viewModel.staleness.daysAgo(viewModel.staleness.lastRHRDate)) }

            MetricCell(
                label: "Sleep",
                value: viewModel.latestSleepMinutes.map { sleepString($0) } ?? "—"
            ) { staleAccessory(viewModel.staleness.daysAgo(viewModel.staleness.lastSleepDate)) }
        }
    }

    @ViewBuilder
    private func staleAccessory(_ daysAgo: Int?) -> some View {
        if let daysAgo {
            Spacer().frame(height: Spacing.baselinePair)
            StalenessWarningBadge(daysAgo: daysAgo)
        }
    }

    private func sleepString(_ minutes: Double) -> String {
        Date.durationString(seconds: Int(minutes) * 60, locale: locale)
    }
}

// MARK: - Training Load Section

struct TrainingLoadSection: View {
    let viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
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
                            // Reading Color Rule v6: a progress fill is a LIVE-STATE MARK, and
                            // live-state is travertine's exclusive territory now that the hero
                            // reading has moved to its metric hue. (Under v5 this fill was inked
                            // because accent was spent on the hero score — that reservation is
                            // gone.) Marks are unrestricted by the contrast rule; zone
                            // classification still reads from the ZoneBadge text above.
                            Rectangle()
                                .fill(ColorTokens.accent)
                                .frame(width: geo.size.width * min(viewModel.acwr / 2.0, 1.0), height: 1)
                        }
                }
                .frame(height: 1)
            }

            HStack(spacing: Spacing.md) {
                // Stagger indices run left→right so the four machine keys label themselves in
                // reading order after the card settles (v6 annotation choreography).
                LoadStatCell(
                    index: 0,
                    label: "ACWR",
                    value: viewModel.acwrZone == .noData && !viewModel.isColdStartActive ? "---" : String(format: "%.2f", viewModel.acwr),
                    isEstimated: viewModel.isColdStartActive
                )
                LoadStatCell(
                    index: 1,
                    label: "ATL",
                    value: viewModel.acwrZone == .noData && !viewModel.isColdStartActive ? "---" : String(format: "%.0f", viewModel.atl),
                    isEstimated: viewModel.isColdStartActive
                )
                LoadStatCell(
                    index: 2,
                    label: "CTL",
                    value: viewModel.acwrZone == .noData && !viewModel.isColdStartActive ? "---" : String(format: "%.0f", viewModel.ctl),
                    isEstimated: viewModel.isColdStartActive
                )
                LoadStatCell(
                    index: 3,
                    label: "TSB",
                    value: viewModel.acwrZone == .noData && !viewModel.isColdStartActive ? "---" : String(format: "%+.0f", viewModel.tsb),
                    isEstimated: viewModel.isColdStartActive
                )
            }
        }
        // v2: the load section is a distinct card plane (surfaceEl + 0.5pt enclosing border).
        .cardStyle()
    }
}

/// One load key + its reading. `ACWR` / `ATL` / `CTL` / `TSB` are machine keys and the
/// estimated flag is a machine qualifier — both are marginalia, so both go through
/// `AnnotationLabel` at `annoSmall`. The reading itself is what the app *says*, so it stays in
/// the working voice with tabular digits.
struct LoadStatCell: View {
    /// Stagger position of this cell's annotation within the load card (v6 choreography).
    var index: Int = 0
    let label: String
    let value: String
    var isEstimated: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            AnnotationLabel(label, size: .small)
                .annotationReveal(index: index)
            // Load reading — tabular digits at the small emphasis size (v5 numeral law).
            Text(value)
                .font(.Tokens.smallLabelMedium)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text1)
            if isEstimated {
                AnnotationLabel(key: "dashboard.label.estimated", size: .small)
                    .annotationReveal(index: index)
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
        // Stage 3 (item 7): header sits OUTSIDE the plate per the section grammar; the rows
        // live on one grouped card plate (`CornerTokens.card`) with inset hairline separators
        // between siblings only — no bare text stacks, no square stroke.
        VStack(alignment: .leading, spacing: 0) {
            RuledSectionHeader(title: "dashboard.section.recentSessions")

            Spacer().frame(height: Spacing.sm)

            VStack(alignment: .leading, spacing: 0) {
                if sessions.isEmpty {
                    Text("dashboard.empty.noSessions")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.sm)
                } else {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.baselinePair) {
                                Text(session.sessionName ?? session.sportType.displayName)
                                    .font(.Tokens.body)
                                    .foregroundStyle(ColorTokens.text1)
                                Text(session.sessionDate.relativeString(locale: locale))
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text2)
                            }
                            Spacer()
                            if let rpe = session.sessionRPE {
                                // `RPE 7` — a machine key carrying a value, i.e. marginalia in
                                // the margin of the row (DESIGN.md v6 annotation layer).
                                AnnotationLabel(
                                    String(format: String(localized: "dashboard.session.rpeValue"), Int(rpe)),
                                    color: ColorTokens.text2
                                )
                                    .annotationReveal(index: index)
                            }
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.sm)

                        if index < sessions.count - 1 {
                            RowSeparator()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
            .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.divider, lineWidth: 0.5))
        }
    }
}
