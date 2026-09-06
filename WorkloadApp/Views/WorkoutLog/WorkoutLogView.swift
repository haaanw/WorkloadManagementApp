import SwiftUI
import SwiftData
import Combine
import StoreKit

struct WorkoutLogView: View {
    @Query(sort: \WorkoutSession.sessionDate, order: .reverse)
    private var sessions: [WorkoutSession]
    @Query private var athletes: [Athlete]
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview
    @State private var showActiveWorkout = false
    @State private var showUpgrade = false
    @State private var selectedSessionType: SessionType? = nil
    @State private var importSuggestions: [WorkoutImportSuggestion] = []
    @State private var importRPESheet: WorkoutImportSuggestion?
    @State private var showMyPrograms = false
    @State private var showProgramImport = false
    @State private var pastDayLog: PastDayLogRequest?
    // Program designation repos (feature 6 wire) — held as @State (deinit trap).
    @State private var designationPlannedRepo: PlannedSessionRepository?
    @State private var designationScheduleRepo: ScheduleRepository?
    @State private var designationProgramRepo: ProgramRepository?
    @State private var selectedTemplateForPreview: WorkoutTemplate?
    @State private var showTemplateEditor = false
    @State private var editingTemplate: WorkoutTemplate?
    @State private var showTemplatePicker = false
    @State private var selectedTemplateForSession: WorkoutTemplate?
    @State private var showLLMImport = false
    // Voice/text capture — LogCaptureSheet parses the captured text and hands back a reviewable
    // draft (onParsed), or the raw text when parsing cannot help (onLogManually).
    @State private var showLogCapture = false
    // The parsed session awaiting review, launched as its own ActiveWorkoutSheet path. Mirrors the
    // verdict's stored-value + boolean chaining; cleared when that sheet closes.
    @State private var parsedSessionForReview: WorkoutVoiceLogService.ParsedSessionDraft?
    @State private var showParsedWorkout = false
    // The transcript carried into a blank session when the athlete falls back to logging by hand.
    @State private var manualLogText: String?
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
                // Editorial screen header (Stage 4a) — the stock large-title nav (system
                // font) is retired; title + actions live in the content, above the filter rail.
                ScreenHeader(title: "workoutLog.nav.title") {
                    HStack(spacing: Spacing.sm) {
                        // One door (U1/R5): "Bring your program" leads, ungated. The legacy
                        // Pro-gated text importer's entry is retired — its bulk-day job is
                        // subsumed by the program door (the sheet itself stays in the target).
                        Menu {
                            Button {
                                showProgramImport = true
                            } label: {
                                Label("workoutLog.menu.bringProgram", systemImage: "square.and.arrow.down")
                            }
                            Button {
                                showPlanToday = true
                            } label: {
                                Label("planToday.menu.label", systemImage: "calendar.badge.plus")
                            }
                            Button {
                                showMyPrograms = true
                            } label: {
                                Label("workoutLog.menu.myPrograms", systemImage: "doc.text.fill")
                            }
                            Button {
                                showLLMImport = true
                            } label: {
                                Label("workoutLog.import.ai", systemImage: "sparkles")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text2)
                        }
                        Button {
                            showLogCapture = true
                        } label: {
                            Image(systemName: "mic")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityIdentifier("workoutLog.voiceLog")
                        Button {
                            showTemplatePicker = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text2)
                        }
                        .buttonStyle(.pressable)
                        .accessibilityIdentifier("workoutLog.startWorkout")
                    }
                }
                .padding(.top, Spacing.md)

                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                SessionTypeFilterBar(selectedType: $selectedSessionType)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                ScrollView {
                    VStack(spacing: 0) {
                        // Slice 2 (R1): the verdict card MOVED to the Today surface
                        // (`TodayProposalSection` on the Dashboard) — the day's proposal now
                        // lives where the day starts, and this tab is what its name says:
                        // capture and history. The VM wiring below stays for the felt-right /
                        // outcome prompts and the plan-refresh seams; the decision surface is
                        // single-mounted on Today.

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
                        // Calendar spine (feature 6): the editable training week + day sheets.
                        ScheduleWeekSection(
                            onLogPastDay: { day, kind in
                                pastDayLog = PastDayLogRequest(day: day, kind: kind)
                            }
                        )
                        .entranceReveal(index: 1)

                        NextMatchSection()
                            .entranceReveal(index: 1)

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
                            },
                            onBringProgram: {
                                showProgramImport = true
                            }
                        )
                        .entranceReveal(index: 2)

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
                                        withAnimation(Motion.resolved(Motion.exit, reduceMotion: reduceMotion)) {
                                            importSuggestions.removeAll { $0.id == suggestion.id }
                                        }
                                    }
                                )
                            }
                        }

                        // Session history
                        if visibleSessions.isEmpty && importSuggestions.isEmpty {
                            // Empty state: one quiet plate (card plane, the one v5 voice) —
                            // not a bare centered text stack.
                            SectionContainer {
                                EmptyStateView(
                                    title: "workoutLog.empty.title",
                                    // Phase A: points at the new capture CTA instead of the
                                    // generic "+" copy. New key (workoutLog.empty.body's VALUE
                                    // is left alone — editing an existing key's text needs a
                                    // hand edit to the string catalog, which is out of scope
                                    // here; a new key auto-extracts on build instead).
                                    message: "workoutLog.empty.bodyCapture"
                                )
                                .padding(.horizontal, Spacing.sm)
                            }
                            .entranceReveal(index: 3)
                        } else {
                            // Demo §3 After: the history section carries a RULED header
                            // (micro-caps + trailing hairline) so it structures the page instead
                            // of a 19pt title floating over a bare list. Rows stay two-line
                            // (SessionRow: name + meta line, date right) for varied density.
                            SectionContainer {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    RuledSectionHeader(title: "workoutLog.section.history")
                                        .padding(.horizontal, Spacing.sm)

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
                            .entranceReveal(index: 3)
                        }

                        Spacer().frame(height: Spacing.lg)
                    }
                }
                .contentMargins(.bottom, Spacing.lg, for: .scrollContent)
                .background(ColorTokens.background)
            }
            // On the VStack, not just the ScrollView inside it: the ScrollView carried the
            // stone plane but the ScreenHeader and filter rail above it did not, so ~90pt of
            // the Log tab rendered on the system's default PURE WHITE — off-palette, and the
            // only non-stone surface in the app. Found by sampling a screenshot, not by
            // reading the code; the four sibling tab roots all set this correctly.
            .background(ColorTokens.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { sessionId in
                if let session = sessions.first(where: { $0.id == sessionId }) {
                    SessionDetailView(session: session)
                }
            }
            .sheet(isPresented: $showActiveWorkout) {
                ActiveWorkoutSheet(
                    template: selectedTemplateForSession,
                    initialNotes: manualLogText
                )
            }
            .onChange(of: showActiveWorkout) { _, isPresented in
                if !isPresented {
                    selectedTemplateForSession = nil
                    manualLogText = nil
                    maybeRequestReview()
                }
            }
            .sheet(isPresented: $showResolvedWorkout) {
                if let plan = resolvedPlanForSession {
                    ActiveWorkoutSheet(resolvedPlan: plan)
                }
            }
            .onChange(of: showResolvedWorkout) { _, isPresented in
                if !isPresented {
                    maybeRequestReview()
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
                    },
                    onBringProgram: {
                        showProgramImport = true
                    }
                )
                .environment(container)
            }
            .sheet(isPresented: $showUpgrade) {
                UpgradeSheet(trigger: .history(lockedWeeks: lockedWeeks))
            }
            .sheet(isPresented: $showLogCapture) {
                LogCaptureSheet(
                    onParsed: { draft in
                        parsedSessionForReview = draft
                        showParsedWorkout = true
                    },
                    onLogManually: { text in
                        // Blank session, transcript carried into its notes so the athlete re-enters
                        // the numbers with their own words in front of them.
                        selectedTemplateForSession = nil
                        manualLogText = text
                        showActiveWorkout = true
                    }
                )
                .environment(container)
            }
            .sheet(isPresented: $showParsedWorkout) {
                if let draft = parsedSessionForReview {
                    ActiveWorkoutSheet(parsedSession: draft)
                }
            }
            .onChange(of: showParsedWorkout) { _, isPresented in
                if !isPresented {
                    parsedSessionForReview = nil
                    maybeRequestReview()
                }
            }
            .sheet(item: $importRPESheet) { suggestion in
                ImportRPESheet(suggestion: suggestion) { rpe in
                    acceptImport(suggestion, rpe: rpe)
                }
            }
            .sheet(isPresented: $showMyPrograms, onDismiss: {
                // Position moves / re-imports change today's proposal.
                if let athlete = athletes.first {
                    ensureProgramDesignation(athleteId: athlete.id)
                    verdictVM?.refresh(athlete: athlete)
                }
            }) {
                NavigationStack {
                    ProgramOverviewView()
                        .environment(container)
                }
            }
            .sheet(isPresented: $showProgramImport, onDismiss: {
                // A newly activated program should propose today immediately.
                if let athlete = athletes.first {
                    ensureProgramDesignation(athleteId: athlete.id)
                    verdictVM?.refresh(athlete: athlete)
                }
            }) {
                ProgramImportSheet()
                    .environment(container)
            }
            .sheet(item: $pastDayLog) { request in
                QuickPastSessionSheet(day: request.day, kind: request.kind)
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
                    ensureProgramDesignation(athleteId: athlete.id)
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
            // Day change while mounted (mirrors NextMatchSection's NSCalendarDayChanged idiom):
            // "today" moved, so re-derive everything day-scoped — the verdict card and the two
            // prompts. In particular the felt-right row must HIDE at midnight (its event is now
            // 2 days old ⇒ ineligible; the repository's record-time guard is the backstop).
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                if let athlete = athletes.first {
                    ensureProgramDesignation(athleteId: athlete.id)
                    verdictVM?.refresh(athlete: athlete)
                }
                refreshFeltRightPrompt()
                refreshOutcomePrompt()
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

    /// Fires the App Store review prompt when a workout sheet closes right after a save.
    /// `ReviewPromptGate` holds the policy; the fresh-save window keys on `createdAt`, so a
    /// cancelled sheet (no new session) never prompts. The delay clears the sheet's
    /// dismissal transition — a prompt mid-transition is silently dropped by the system.
    private func maybeRequestReview() {
        #if DEBUG && targetEnvironment(simulator)
        // The capture harness closes workout sheets over freshly seeded sessions — a review
        // alert mid-run would wedge every subsequent plate.
        if ProcessInfo.processInfo.arguments.contains("SCREENSHOT_MODE") { return }
        #endif
        let defaults = UserDefaults.standard
        let lastPromptedAt = defaults.object(forKey: ReviewPromptGate.lastPromptedAtKey) as? Date
        guard ReviewPromptGate.shouldPrompt(
            completedSessionCount: sessions.count,
            latestSessionCreatedAt: sessions.map(\.createdAt).max(),
            lastPromptedAt: lastPromptedAt
        ) else { return }
        defaults.set(Date.now, forKey: ReviewPromptGate.lastPromptedAtKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            requestReview()
        }
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

        withAnimation(Motion.resolved(Motion.exit, reduceMotion: reduceMotion)) {
            importSuggestions.removeAll { $0.id == suggestion.id }
        }
    }

    /// The program→proposal wire (feature 6, epic 1): designate today's program day when
    /// nothing is designated yet, so the verdict card proposes it without a manual
    /// "Plan Today" step.
    private func ensureProgramDesignation(athleteId: UUID) {
        if designationPlannedRepo == nil {
            designationPlannedRepo = PlannedSessionRepository(modelContext: modelContext)
            designationScheduleRepo = ScheduleRepository(modelContext: modelContext)
            designationProgramRepo = ProgramRepository(modelContext: modelContext)
        }
        guard let plannedRepo = designationPlannedRepo,
              let scheduleRepo = designationScheduleRepo,
              let programRepo = designationProgramRepo else { return }
        ProgramScheduleService.ensureTodayDesignation(
            athleteId: athleteId,
            plannedSessionRepo: plannedRepo,
            scheduleRepo: scheduleRepo,
            programRepo: programRepo
        )
    }
}

/// A past-day retroactive logging request (calendar spine day sheet → QuickPastSessionSheet).
struct PastDayLogRequest: Identifiable {
    let day: Date
    let kind: ScheduleEntryKind
    var id: String { "\(day.timeIntervalSince1970)-\(kind.rawValue)" }
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
            VStack(spacing: Spacing.md) {
                VStack(spacing: Spacing.xs) {
                    Text(suggestion.name)
                        .font(.Tokens.sectionHead)
                        .foregroundStyle(ColorTokens.text1)
                    // v6: timestamp + duration + unitized distance — the annotation voice.
                    HStack(spacing: Spacing.xs) {
                        AnnotationLabel(
                            suggestion.date.relativeString(locale: locale),
                            color: ColorTokens.text2
                        )
                        AnnotationLabel(
                            Date.durationString(seconds: suggestion.durationSeconds, locale: locale),
                            color: ColorTokens.text2
                        )
                        if let dist = suggestion.distanceMeters {
                            AnnotationLabel(
                                String(format: "%.1f km", dist / 1000),
                                color: ColorTokens.text2
                            )
                        }
                    }
                }

                VStack(spacing: Spacing.xs) {
                    Text("workoutLog.rpe.prompt")
                        .font(.Tokens.body)
                        .foregroundStyle(ColorTokens.text1)
                    Text(String(format: String(localized: "workoutLog.rpe.valueLabeled"), Int(rpe)))
                        .font(.Tokens.pageTitle)
                        .monospacedDigit()
                        .foregroundStyle(ColorTokens.text1)
                    Slider(value: $rpe, in: 1...10, step: 1)
                        .tint(ColorTokens.text2)
                    // Scale end labels — axis labels on an instrument, so the annotation voice (v6).
                    HStack {
                        AnnotationLabel(key: "workoutLog.rpe.easy", size: .small)
                        Spacer()
                        AnnotationLabel(key: "workoutLog.rpe.maximal", size: .small)
                    }
                }

                Spacer()
            }
            .padding(Spacing.md)
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
                // v6: the meta line is pure marginalia — a duration, a unitized volume and an
                // RPE key. Annotation voice, on `text2` (rule 7: annotation the athlete reads
                // for real takes the stronger ink, not the `text3` default).
                HStack(spacing: Spacing.xs) {
                    AnnotationLabel(
                        Date.durationString(seconds: session.durationSeconds, locale: locale),
                        color: ColorTokens.text2
                    )
                    if session.totalVolume > 0 {
                        AnnotationLabel(
                            String(format: "%.0f kg", session.totalVolume),
                            color: ColorTokens.text2
                        )
                    }
                    if let rpe = session.sessionRPE {
                        AnnotationLabel(
                            String(format: String(localized: "dashboard.session.rpeValue"), Int(rpe)),
                            color: ColorTokens.text2
                        )
                    }
                }
            }
            Spacer()
            // A timestamp — annotation's canonical content.
            AnnotationLabel(session.sessionDate.relativeString(locale: locale))
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
            .padding(.horizontal, Spacing.sm)
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
                .foregroundStyle(isSelected ? ColorTokens.text1 : ColorTokens.text2)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .overlay(alignment: .bottom) {
                    if isSelected {
                        // The active filter is marked by an INK underline (v5: ink carries
                        // chrome selection here; the accent is reserved for the hero score
                        // and live-state marks).
                        Rectangle()
                            .fill(ColorTokens.text1)
                            .frame(height: 1.5)
                            .padding(.horizontal, Spacing.sm)
                    }
                }
        }
        .buttonStyle(.pressable)
    }
}
