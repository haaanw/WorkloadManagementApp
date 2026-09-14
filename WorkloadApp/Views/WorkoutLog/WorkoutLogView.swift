import SwiftUI
import SwiftData
import Combine
import StoreKit

struct WorkoutLogView: View {
    @Query(sort: \WorkoutSession.sessionDate, order: .reverse)
    private var sessions: [WorkoutSession]
    @Query private var athletes: [Athlete]
    /// U8: the hero plate shows only while there is no program to schedule. Reactive, so
    /// importing one replaces it without a reload.
    @Query private var programs: [TrainingProgram]
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview
    @State private var showActiveWorkout = false
    @State private var showUpgrade = false
    @State private var selectedSessionType: SessionType? = nil
    @State private var showMyPrograms = false
    @State private var showProgramImport = false
    @State private var pastDayLog: PastDayLogRequest?
    // Program designation repos (feature 6 wire) — held as @State (deinit trap).
    @State private var designationPlannedRepo: PlannedSessionRepository?
    @State private var designationScheduleRepo: ScheduleRepository?
    @State private var designationProgramRepo: ProgramRepository?
    @State private var showTemplatePicker = false
    @State private var selectedTemplateForSession: WorkoutTemplate?
    // Voice/text capture — LogCaptureSheet parses the captured text and hands back a reviewable
    // draft (onParsed), or the raw text when parsing cannot help (onLogManually).
    @State private var showLogCapture = false
    // The parsed session awaiting review, launched as its own ActiveWorkoutSheet path. Mirrors the
    // verdict's stored-value + boolean chaining; cleared when that sheet closes.
    @State private var parsedSessionForReview: WorkoutVoiceLogService.ParsedSessionDraft?
    @State private var showParsedWorkout = false
    // The transcript carried into a blank session when the athlete falls back to logging by hand.
    @State private var manualLogText: String?
    // The verdict's resolved workout, captured on the card's start action and launched as a
    // dedicated ActiveWorkoutSheet path (verdict → workout). Cleared when that sheet closes.
    @State private var resolvedPlanForSession: ResolvedSessionPlan?
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

    private var activeProgram: TrainingProgram? {
        guard let athleteId = athletes.first?.id else { return nil }
        return programs.first { $0.isActive && !$0.isArchived && $0.athleteId == athleteId }
    }

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
                // U7 · ONE DOOR. The header carried three icons — an ellipsis menu of four
                // flat entries, a mic, and a "+" — behind which sat four doors to two jobs:
                // the program was offered twice (menu + template empty state), authoring three
                // times, and "Plan Today" duplicated the calendar spine that already designates
                // days. The header now keeps exactly one action, and it is the one this tab
                // exists for: CAPTURE. Say it, type it, paste a workout and log by hand are all
                // modes of that one sheet, not four doors.
                //
                // Where the retired entries went. The program door is the week strip's own
                // header (it already prints the program's name and position, so a separate card
                // would have repeated it). "Plan Today" died: tapping the day in the spine does
                // that job. Template authoring moved down into My Programs (U8). The AI
                // single-workout importer lost its top-level entry — pasting a workout into the
                // capture editor is the same job, and its bulk-day job belongs to the program
                // door; the sheet itself stays, reached from `ActiveWorkoutSheet`.
                ScreenHeader(title: "workoutLog.nav.title") {
                    Button {
                        showLogCapture = true
                    } label: {
                        Image(systemName: "mic")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("workoutLog.voiceLog")
                }
                .padding(.top, Spacing.md)

                // The masthead rules bracketing the filter rail — area hairlines (v6.3), so
                // they take the strain tint via the one `AreaRule` implementation.
                AreaRule()
                SessionTypeFilterBar(selectedType: $selectedSessionType)
                AreaRule()

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

                        // Calendar spine (feature 6): the editable training week + day sheets.
                        // Its header doubles as the program door (U7) — name, position, chevron.
                        ScheduleWeekSection(
                            onLogPastDay: { day, kind in
                                pastDayLog = PastDayLogRequest(day: day, kind: kind)
                            },
                            onOpenProgram: {
                                showMyPrograms = true
                            },
                            // U17: the plan-led start was reachable only from Today's verdict
                            // card. The day cell that already names the session now starts it.
                            onStartPlannedSession: { plan in
                                resolvedPlanForSession = plan
                            }
                        )
                        .entranceReveal(index: 1)

                        // U8: the program door is the page's content when there is nothing to
                        // schedule yet. The template CAROUSEL is gone from this tab entirely —
                        // it sold authoring twice before the program was asked for once. What
                        // replaces it is one hero plate, one ink pill, and one quiet line for
                        // the athlete who has no program; templates themselves live on in My
                        // Programs, where the things you own are listed.
                        if activeProgram == nil {
                            BringYourProgramSection(
                                onBringProgram: { showProgramImport = true },
                                onStartFromTemplate: { showTemplatePicker = true }
                            )
                            .entranceReveal(index: 2)
                        }

                        // Next match — the one schedule-shaped plan object (ADR-0002). Always
                        // renders; the empty state ("no scheduled match") is a normal, calm one.
                        NextMatchSection()
                            .entranceReveal(index: 2)

                        // U4: the watch-import BANNER is retired. A watch workout is not a
                        // suggestion awaiting an Add tap and an RPE sheet — it is a session
                        // the athlete already recorded, so it is already in the history list
                        // below, carrying a quiet "logged from watch" mark on its row.

                        // Session history
                        if visibleSessions.isEmpty {
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
            // v6.3 "The Area Tint": Log/capture is the STRAIN area (rust) — this is where
            // strain is produced and recorded. Section rules and row separators take the 18%
            // tint; the program door takes the 4% hero wash.
            .metricArea(.strain)
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
            // Presented via .sheet(item:) — the boolean-plus-optional pair raced under load
            // and presented an EMPTY sheet (the Today-surface class, fixed 2026-09-09). The
            // Log-tab door (U17) is the first live writer of this state.
            .sheet(item: $resolvedPlanForSession, onDismiss: {
                maybeRequestReview()
                // The prescription may now be completed — refresh the card + prompts.
                if let athlete = athletes.first {
                    verdictVM?.refresh(athlete: athlete)
                    refreshFeltRightPrompt()
                    refreshOutcomePrompt()
                }
            }) { plan in
                ActiveWorkoutSheet(resolvedPlan: plan)
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
            // U7/U8: the template preview + editor, the AI single-workout importer and the
            // "Plan Today" sheet all lost their entries from this tab. Previewing and editing a
            // template happen in My Programs, beside the templates themselves; planning a day
            // is what tapping that day in the spine above already does.
            // Watch workouts log themselves (v1.7.3 · U4). This is a second trigger, not the
            // only one: `MainTabView` runs the same import on every foreground, because a
            // `TabView` child's `.task` fires once per app process and a watch workout
            // reaches HealthKit minutes after it ends — which is exactly how the retired
            // banner came to show three stale walks and miss the session that mattered.
            .task {
                await WatchWorkoutImportService.run(
                    healthKit: container.healthKitService,
                    modelContext: modelContext,
                    syncService: container.syncService
                )
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

// MARK: - Bring your program (U8)

/// The Log tab's one plate when there is no program yet: a sentence that states the trade the
/// product is actually making, the screen's ONE ink pill, and a quiet second line for the
/// athlete who has no program to bring.
///
/// It replaces a card that sold template authoring TWICE — as a hero key and again as the
/// section header's action — while offering the program once, as the smaller of two equal keys.
/// Authoring did not die with it: it survives as the last row of My Programs, on the screen
/// that already lists what you own. What left is the CREATION surface's claim on the top level.
struct BringYourProgramSection: View {
    let onBringProgram: () -> Void
    let onStartFromTemplate: () -> Void

    var body: some View {
        SectionContainer {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("workoutLog.program.pitch")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                    .fixedSize(horizontal: false, vertical: true)

                PrimaryActionButton(title: "workoutLog.menu.bringProgram") {
                    onBringProgram()
                }
                .accessibilityIdentifier("workoutLog.bringProgram")

                Button {
                    Haptics.tap()
                    onStartFromTemplate()
                } label: {
                    Text("workoutLog.program.orTemplate")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.pressable)
                .accessibilityIdentifier("workoutLog.startWorkout")
            }
            // v6.3: with nothing else on the screen this plate is the Log tab's hero — the one
            // card that takes the strain area's 4% wash.
            .cardStyle(isHero: true)
            .padding(.horizontal, Spacing.sm)
        }
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
                    // U22: the work cell asks `SessionWorkReading`, never `totalVolume`
                    // directly — the stored field is tonnage on a lifting session and
                    // METRES on a walk, so the literal " kg" that used to live here read
                    // a 1.1 km walk back as "1106 kg".
                    if let work = SessionWorkReading.label(
                        for: session,
                        unit: session.athlete?.weightUnit ?? .kg,
                        locale: locale
                    ) {
                        AnnotationLabel(work, color: ColorTokens.text2)
                    }
                    if let rpe = session.sessionRPE {
                        AnnotationLabel(
                            String(format: String(localized: "dashboard.session.rpeValue"), Int(rpe)),
                            color: ColorTokens.text2
                        )
                    }
                    // U4: the whole surface a watch-logged session gets. It is a provenance
                    // mark in the marginalia, not a prompt and not a call to action — the
                    // session is already logged and the athlete has nothing to do about it.
                    // It reads on `text3`, one step quieter than the readings beside it.
                    if session.healthKitWorkoutUUID != nil {
                        AnnotationLabel(key: "workoutLog.session.fromWatch")
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
