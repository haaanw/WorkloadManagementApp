import SwiftUI
import SwiftData

struct WorkoutLogView: View {
    @Query(sort: \WorkoutSession.sessionDate, order: .reverse)
    private var sessions: [WorkoutSession]
    @Query private var athletes: [Athlete]
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showActiveWorkout = false
    @State private var showUpgrade = false
    @State private var selectedSessionType: SessionType? = nil
    @State private var importSuggestions: [WorkoutImportSuggestion] = []
    @State private var importRPESheet: WorkoutImportSuggestion?
    @State private var showMyPrograms = false
    @State private var showTextImport = false
    @State private var selectedTemplateForPreview: WorkoutTemplate?
    @State private var showTemplateEditor = false
    @State private var editingTemplate: WorkoutTemplate?
    @State private var showTemplatePicker = false
    @State private var selectedTemplateForSession: WorkoutTemplate?
    @State private var showLLMImport = false
    @State private var showPlanToday = false
    // The verdict's resolved workout, captured on the card's start action and launched as a
    // dedicated ActiveWorkoutSheet path (verdict → workout). Cleared when that sheet closes.
    @State private var resolvedPlanForSession: ResolvedSessionPlan?
    @State private var showResolvedWorkout = false
    @State private var verdictVM: TodayVerdictViewModel?
    // Phase 45 — held stably so the onDecisionRecorded closure logs into one instance (SC4 seam).
    @State private var verdictRepository: VerdictEventRepository?
    // Phase 45 — a past planned-day decision awaiting its no-guilt post-session outcome.
    @State private var outcomeEvent: VerdictEvent?
    // v2.1 dogfood (item 6) — YESTERDAY's differing-verdict decision, promptable strictly today
    // (next calendar day only; missed ⇒ stays absent, no back-fill).
    @State private var feltRightEvent: VerdictEvent?
    // Phase 45 (METRIC-03) — the Sean-Ellis disappointment prompt + the revealed-WTP paywall hop.
    @State private var showSeanEllis = false
    @State private var showWTPUpgrade = false
    @State private var seanEllisEventCount = 0

    private var visibleSessions: [WorkoutSession] {
        let base = container.subscriptionService.isPro
            ? sessions
            : SubscriptionService.filterSessionsForFree(sessions)
        guard let type = selectedSessionType else { return base }
        return base.filter { $0.sessionType == type }
    }

    private var lockedWeeks: Int {
        guard !container.subscriptionService.isPro else { return 0 }
        let visible = SubscriptionService.filterSessionsForFree(sessions)
        return SubscriptionService.lockedWeeks(
            totalSessions: sessions.count,
            visibleSessions: visible.count
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                SessionTypeFilterBar(selectedType: $selectedSessionType)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                ScrollView {
                    VStack(spacing: 0) {
                        // Today's suggest-and-confirm verdict card — only when a today-plan exists.
                        // No today-plan ⇒ vm.display == nil ⇒ nothing renders (screen byte-unchanged).
                        if let vm = verdictVM, let display = vm.display, let athlete = athletes.first {
                            SectionContainer {
                                TodayVerdictCard(
                                    display: display,
                                    weightUnit: athlete.weightUnit,
                                    canStartWorkout: vm.canStartResolvedWorkout,
                                    onAccept: { vm.accept() },
                                    onKeepPlan: { vm.keepPlan() },
                                    onFeel: { vm.feelOverride($0) },
                                    onStartWorkout: {
                                        // Derived from the persisted decision state — the Start CTA only
                                        // renders when canStartWorkout is true, so a resolved plan is
                                        // available here. Assert the invariant in DEBUG; never no-op.
                                        guard let plan = vm.resolvedPlanForWorkout else {
                                            assertionFailure("Start tapped without a resolvable plan — canStartWorkout/resolvedPlanForWorkout drifted")
                                            return
                                        }
                                        resolvedPlanForSession = plan
                                        showResolvedWorkout = true
                                    }
                                )
                                .padding(.horizontal, Spacing.sm)
                            }
                        }

                        // v2.1 dogfood — the next-day "felt right?" capture. Renders ONLY on the
                        // calendar day after a differing-verdict day (criterion 3: judged next-day,
                        // logged same-day, never retro-rated). Sits under the verdict-card slot so
                        // yesterday's judgment lives beside today's call.
                        if let event = feltRightEvent, let athlete = athletes.first {
                            SectionContainer {
                                FeltRightPromptRow(
                                    event: event,
                                    weightUnit: athlete.weightUnit
                                ) { answer in
                                    verdictRepository?.recordFeltRight(answer, for: event, at: .now)
                                    withAnimation(Motion.resolved(Motion.exit, reduceMotion: reduceMotion)) {
                                        feltRightEvent = nil
                                    }
                                }
                                .padding(.horizontal, Spacing.sm)
                            }
                        }

                        // Next match — the one schedule-shaped plan object (ADR-0002). Always
                        // renders; empty state ("no scheduled match") is a normal, calm state.
                        // Stage 2 wires the date into the verdict; here it is set/clear only.
                        NextMatchSection()

                        // Template carousel (My Templates section — header lives inside)
                        TemplateCarouselSection(
                            onEditTemplate: { template in
                                editingTemplate = template
                                showTemplateEditor = true
                            },
                            onStartFromTemplate: { template in
                                selectedTemplateForSession = template
                                showActiveWorkout = true
                            },
                            onCreateTemplate: {
                                editingTemplate = nil
                                showTemplateEditor = true
                            },
                            onPreviewTemplate: { template in
                                selectedTemplateForPreview = template
                            }
                        )

                        // HealthKit import suggestions
                        if !importSuggestions.isEmpty {
                            SectionContainer {
                                WorkoutImportBanner(
                                    imports: importSuggestions,
                                    onAccept: { suggestion in
                                        importRPESheet = suggestion
                                    },
                                    onDismiss: { suggestion in
                                        WorkoutImportService.dismissSuggestion(suggestion)
                                        withAnimation(Motion.exit) {
                                            importSuggestions.removeAll { $0.id == suggestion.id }
                                        }
                                    }
                                )
                            }
                        }

                        // Session history
                        if visibleSessions.isEmpty && importSuggestions.isEmpty {
                            VStack(spacing: Spacing.sm) {
                                Text("workoutLog.empty.title")
                                    .font(.Tokens.sectionHead)
                                    .foregroundStyle(ColorTokens.text1)
                                Text("workoutLog.empty.body")
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text2)
                            }
                            .padding(.vertical, Spacing.xl)
                            .frame(maxWidth: .infinity)
                        } else {
                            SectionContainer(header: "workoutLog.section.history") {
                                VStack(spacing: 0) {
                                    ForEach(visibleSessions, id: \.id) { session in
                                        NavigationLink(value: session.id) {
                                            SessionRow(session: session)
                                        }
                                        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                                        .transition(.opacity)

                                        RowSeparator()
                                    }

                                    if lockedWeeks > 0 {
                                        HistoryTeaserBanner(lockedWeeks: lockedWeeks) {
                                            showUpgrade = true
                                        }
                                    }
                                }
                                .animation(Motion.resolved(Motion.entrance, reduceMotion: reduceMotion), value: visibleSessions.count)
                            }
                        }

                        Spacer().frame(height: Spacing.lg)
                    }
                }
                .contentMargins(.bottom, Spacing.lg, for: .scrollContent)
                .background(ColorTokens.background)
            }
            .navigationTitle("workoutLog.nav.title")
            .toolbarBackground(ColorTokens.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: UUID.self) { sessionId in
                if let session = sessions.first(where: { $0.id == sessionId }) {
                    SessionDetailView(session: session)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        Menu {
                            Button {
                                showPlanToday = true
                            } label: {
                                Label("planToday.menu.label", systemImage: "calendar.badge.plus")
                            }
                            Button {
                                showLLMImport = true
                            } label: {
                                Label("workoutLog.import.ai", systemImage: "sparkles")
                            }
                            Button {
                                showMyPrograms = true
                            } label: {
                                Label("workoutLog.menu.myPrograms", systemImage: "doc.text.fill")
                            }
                            Button {
                                if container.subscriptionService.isPro {
                                    showTextImport = true
                                } else {
                                    showUpgrade = true
                                }
                            } label: {
                                Label("workoutLog.import.text", systemImage: "doc.plaintext")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(ColorTokens.text2)
                        }
                        Button {
                            showTemplatePicker = true
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(ColorTokens.text1)
                        }
                        .accessibilityIdentifier("workoutLog.startWorkout")
                    }
                }
            }
            .sheet(isPresented: $showActiveWorkout) {
                ActiveWorkoutSheet(
                    template: selectedTemplateForSession
                )
            }
            .onChange(of: showActiveWorkout) { _, isPresented in
                if !isPresented {
                    selectedTemplateForSession = nil
                }
            }
            .sheet(isPresented: $showResolvedWorkout) {
                if let plan = resolvedPlanForSession {
                    ActiveWorkoutSheet(resolvedPlan: plan)
                }
            }
            .onChange(of: showResolvedWorkout) { _, isPresented in
                if !isPresented {
                    resolvedPlanForSession = nil
                    // The verdict's prescription may now be completed — refresh the card + prompts.
                    if let athlete = athletes.first {
                        verdictVM?.refresh(athlete: athlete)
                        refreshFeltRightPrompt()
                        refreshOutcomePrompt()
                    }
                }
            }
            .sheet(isPresented: $showTemplatePicker) {
                TemplatePickerSheet(
                    onSelectTemplate: { template in
                        selectedTemplateForSession = template
                        showActiveWorkout = true
                    },
                    onStartBlank: {
                        selectedTemplateForSession = nil
                        showActiveWorkout = true
                    },
                    onCreateTemplate: {
                        editingTemplate = nil
                        showTemplateEditor = true
                    }
                )
                .environment(container)
            }
            .sheet(isPresented: $showUpgrade) {
                UpgradeSheet(trigger: .history(lockedWeeks: lockedWeeks))
            }
            .sheet(item: $importRPESheet) { suggestion in
                ImportRPESheet(suggestion: suggestion) { rpe in
                    acceptImport(suggestion, rpe: rpe)
                }
            }
            .sheet(isPresented: $showMyPrograms) {
                NavigationStack {
                    TemplateListView()
                        .environment(container)
                }
            }
            .sheet(isPresented: $showTextImport) {
                TextTemplateImportSheet()
                    .environment(container)
            }
            .sheet(item: $selectedTemplateForPreview) { template in
                TemplatePreviewSheet(
                    template: template,
                    onEdit: {
                        selectedTemplateForPreview = nil
                        editingTemplate = template
                        showTemplateEditor = true
                    }
                )
                .environment(container)
            }
            .sheet(isPresented: $showLLMImport) {
                WorkoutImportSheet()
                    .environment(container)
            }
            .sheet(isPresented: $showPlanToday) {
                PlanTodaySheet()
                    .environment(container)
            }
            .sheet(isPresented: $showTemplateEditor) {
                if let athleteId = athletes.first?.id {
                    TemplateEditorSheet(
                        coachId: athleteId,
                        existingTemplate: editingTemplate
                    )
                    .environment(container)
                }
            }
            .task {
                await loadImportSuggestions()
            }
            .task(id: athletes.first?.id) {
                // Construct the verdict VM once; refresh against the current athlete's today-plan.
                // SC4 ordering guard: wire the production logger seam at construction so the verdict
                // surface can NEVER be reached without a VerdictEvent being recorded per decision.
                if verdictVM == nil {
                    let vm = TodayVerdictViewModel(modelContext: modelContext)
                    let repository = VerdictEventRepository(modelContext: modelContext)
                    verdictRepository = repository
                    let loggedAthlete = athletes.first
                    vm.onDecisionRecorded = { [weak vm] decision in
                        guard let vm else { return }
                        let delta = (decision.adjustedTopSetKg ?? decision.plannedTopSetKg) - decision.plannedTopSetKg
                        repository.log(
                            decidedAt: decision.decidedAt,
                            planDate: .now,                 // today's planned session; model applies start-of-day
                            verdictKindRaw: vm.lastHeadlineVerdictRaw ?? "go",
                            plannedTopSetKg: decision.plannedTopSetKg,
                            adjustedTopSetKg: decision.adjustedTopSetKg,
                            deltaKg: delta,
                            differed: decision.hadAdjustment,
                            actionRaw: verdictActionRaw(decision.action),
                            regionRaw: vm.lastHeadlineRegionRaw ?? MuscleRegion.fullBody.rawValue,
                            reasonLine: decision.reasonLine,
                            confidenceNote: vm.display?.confidenceNote,
                            prescriptionId: vm.currentPrescriptionId,
                            suggestedBackoffSetCut: decision.suggestedBackoffSetCut,
                            suggestedRPECap: decision.suggestedRPECap,
                            // v2.1 dogfood criterion 4: an explicit true/false from the headline
                            // VerdictResult.matchProximity — a proximity microdose is never logged
                            // as a plain "modify". (nil stays reserved for pre-v2.1 rows.)
                            matchProximity: vm.lastHeadlineMatchProximity,
                            athlete: loggedAthlete
                        )
                    }
                    verdictVM = vm
                }
                if let athlete = athletes.first {
                    verdictVM?.refresh(athlete: athlete)
                }
                refreshFeltRightPrompt()
                refreshOutcomePrompt()
                refreshSeanEllisPrompt()
            }
            .onChange(of: showPlanToday) { _, isPresented in
                // After planning today's session, re-read so the verdict card appears.
                if !isPresented, let athlete = athletes.first {
                    verdictVM?.refresh(athlete: athlete)
                    refreshFeltRightPrompt()
                    refreshOutcomePrompt()
                }
            }
            .sheet(item: $outcomeEvent) { event in
                VerdictOutcomeSheet(
                    event: event,
                    weightUnit: athletes.first?.weightUnit ?? .kg
                ) { selection in
                    verdictRepository?.recordOutcome(selection, for: event, at: .now)
                    outcomeEvent = nil
                }
            }
            .sheet(isPresented: $showSeanEllis) {
                SeanEllisPromptSheet { answer in
                    SeanEllisStore().recordAnswer(answer, atEventCount: seanEllisEventCount, on: .now)
                    showSeanEllis = false
                    // A "very disappointed" answer is the strongest stated signal — route it into the
                    // existing RevenueCat paywall to capture the REVEALED intent (card-on-file).
                    if answer == .very {
                        showWTPUpgrade = true
                    }
                }
            }
            // WTP / card-on-file hop: REUSE the existing paywall (no new trigger case, no new paywall
            // code). DEFERRED-EXTERNAL: RevenueCat dashboard trial→paid offering config (intro-trial
            // product on athlete_pro) + real-charge testing are external/human (RevenueCatConfig is
            // gitignored). The CODE path is live here.
            .sheet(isPresented: $showWTPUpgrade) {
                UpgradeSheet(trigger: .athletePro)
                    .environment(container)
            }
        }
    }

    /// Gate the Sean-Ellis prompt: after N logged verdict sessions, ask once per eligibility bracket.
    /// The store is local-only + deterministic; `.now` only stamps the recorded answer, never the gate.
    private func refreshSeanEllisPrompt() {
        let count = verdictRepository?.fetchAll(athlete: athletes.first).count ?? 0
        seanEllisEventCount = count
        if SeanEllisStore().shouldPrompt(verdictEventCount: count) {
            showSeanEllis = true
        }
    }

    /// Surface the most recent PAST planned-day decision that still has no recorded outcome (never
    /// mid-session — `before` is start-of-day today, so today's decisions don't trigger the prompt).
    /// When the inline next-day "felt right?" row owns the same event, the modal stands down —
    /// answering the row mirrors into the outcome field, so the athlete is never asked twice.
    private func refreshOutcomePrompt() {
        let awaiting = verdictRepository?.mostRecentAwaitingOutcome(
            athlete: athletes.first,
            before: Calendar.current.startOfDay(for: .now)
        )
        outcomeEvent = (awaiting?.id == feltRightEvent?.id) ? nil : awaiting
    }

    /// v2.1 dogfood (item 6) — strict next-day eligibility via the pure engine: promptable ONLY on
    /// the calendar day after a differing-verdict day; same-day and 2+-day-old events never surface
    /// (a missed day records as absent — no back-fill UI). `.now`/`.current` are read once here at
    /// the boundary; the engine stays injected.
    private func refreshFeltRightPrompt() {
        let events = verdictRepository?.fetchRecent(days: 3, athlete: athletes.first) ?? []
        feltRightEvent = FeltRightPromptEngine.eligibleEvent(
            events: events,
            asOf: .now,
            calendar: .current
        )
    }

    private func loadImportSuggestions() async {
        guard container.healthKitService.isAuthorized else { return }
        importSuggestions = await WorkoutImportService.findUnmatchedWorkouts(
            healthKit: container.healthKitService,
            modelContext: modelContext
        )
    }

    private func acceptImport(_ suggestion: WorkoutImportSuggestion, rpe: Double) {
        guard let athlete = athletes.first else { return }
        let session = WorkoutImportService.createSession(
            from: suggestion,
            sessionRPE: rpe,
            athlete: athlete,
            modelContext: modelContext
        )
        modelContext.insert(session)
        try? modelContext.save()

        // Run pipeline
        do {
            _ = try WorkoutPipeline.processSession(
                session,
                athlete: athlete,
                modelContext: modelContext,
                syncService: container.syncService
            )
        } catch {
            print("Import pipeline error: \(error)")
        }

        withAnimation(Motion.exit) {
            importSuggestions.removeAll { $0.id == suggestion.id }
        }
    }
}

// MARK: - Phase 45 verdict-event action mapping

/// Map a `VerdictDecision.action` to the composite `VerdictEvent.actionRaw` token.
private func verdictActionRaw(_ action: VerdictAction) -> String {
    switch action {
    case .accepted: return "accepted"
    case .keptPlan: return "keptPlan"
    case .feel(.feelingStrong): return "feelStrong"
    case .feel(.feelingRough): return "feelRough"
    }
}

// MARK: - Import RPE Sheet

struct ImportRPESheet: View {
    let suggestion: WorkoutImportSuggestion
    let onConfirm: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var rpe: Double = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(suggestion.name)
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)
                    HStack(spacing: Spacing.xs) {
                        Text(suggestion.date.relativeString(locale: locale))
                        Text(Date.durationString(seconds: suggestion.durationSeconds, locale: locale))
                        if let dist = suggestion.distanceMeters {
                            Text(String(format: "%.1f km", dist / 1000))
                        }
                    }
                    .font(.Tokens.label)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.text2)
                }

                VStack(spacing: 8) {
                    Text("workoutLog.rpe.prompt")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                    Text(String(format: String(localized: "workoutLog.rpe.valueLabeled"), Int(rpe)))
                        .font(.Tokens.pageTitle)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text1)
                    Slider(value: $rpe, in: 1...10, step: 1)
                        .tint(ColorTokens.text2)
                    HStack {
                        Text("workoutLog.rpe.easy").font(.Tokens.label).foregroundStyle(ColorTokens.text3)
                        Spacer()
                        Text("workoutLog.rpe.maximal").font(.Tokens.label).foregroundStyle(ColorTokens.text3)
                    }
                }

                Spacer()
            }
            .padding(24)
            .background(ColorTokens.background)
            .navigationTitle("workoutLog.import.navTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.import") {
                        onConfirm(rpe)
                        dismiss()
                    }
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                }
            }
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: WorkoutSession
    @Environment(\.locale) private var locale

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(session.sessionName ?? session.sportType.displayName)
                    .font(.Tokens.bodyMedium)
                    .foregroundStyle(ColorTokens.text1)
                HStack(spacing: Spacing.xs) {
                    Text(Date.durationString(seconds: session.durationSeconds, locale: locale))
                    if session.totalVolume > 0 {
                        Text(String(format: "%.0f kg", session.totalVolume))
                    }
                    if let rpe = session.sessionRPE {
                        Text(String(format: String(localized: "dashboard.session.rpeValue"), Int(rpe)))
                    }
                }
                .font(.Tokens.smallLabel)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.text2)
            }
            Spacer()
            Text(session.sessionDate.relativeString(locale: locale))
                .font(.Tokens.smallLabel)
                .foregroundStyle(ColorTokens.text3)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(ColorTokens.background)
    }
}

// MARK: - Session Type Filter Bar

struct SessionTypeFilterBar: View {
    @Binding var selectedType: SessionType?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                SessionFilterChip(label: Text("workoutLog.filter.all"), isSelected: selectedType == nil) {
                    selectedType = nil
                }
                ForEach(SessionType.allCases) { type in
                    SessionFilterChip(label: Text(verbatim: type.displayName), isSelected: selectedType == type) {
                        selectedType = type
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 40)
        .background(ColorTokens.background)
    }
}

private struct SessionFilterChip: View {
    let label: Text
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            // Selection-change feedback only (not a re-tap of the already-active segment).
            if !isSelected { Haptics.select() }
            action()
        } label: {
            label
                .font(isSelected ? .Tokens.smallLabelMedium : .Tokens.smallLabel)
                .foregroundStyle(isSelected ? ColorTokens.accent : ColorTokens.text2)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .overlay(alignment: .leading) {
                    if isSelected {
                        // v2: the active segment carries a 2pt accent edge (accent = active).
                        Rectangle()
                            .fill(ColorTokens.accent)
                            .frame(width: 2)
                    }
                }
        }
        .buttonStyle(.pressable)
    }
}
