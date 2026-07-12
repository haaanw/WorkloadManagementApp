import SwiftUI
import SwiftData

struct ActiveWorkoutSheet: View {
    var template: WorkoutTemplate?
    /// The verdict-resolved plan to launch. Mutually exclusive with `template` (see the two inits):
    /// a sheet is EITHER a template/blank session OR a resolved-prescription session — never both.
    var resolvedPlan: ResolvedSessionPlan?

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Query private var athletes: [Athlete]
    @State private var sessionName = ""
    @State private var sportType: SportType = .lifting
    @State private var sessionType: SessionType = .strength
    @State private var sessionStartChoice: SessionStartChoice = .strength
    // v2.1 beachhead: match tier for `.match`-type sessions (pickup → scrimmage → match).
    // nil = untouched picker, treated as pickup by the carry model (safe default).
    @State private var matchTier: MatchTier? = nil
    @State private var entries: [ExerciseEntryDraft] = []
    @State private var sessionRPE: Double = 5
    @State private var startTime = Date.now
    @State private var showExercisePicker = false
    @State private var showFinishConfirmation = false
    @State private var newPRs: [PersonalRecord] = []
    @State private var showPRCelebration = false
    @State private var spikeAlert: WorkloadCalculator.SpikeAlert?
    @State private var showSpikeAlert = false
    @State private var saveAsTemplate = false
    @State private var templateName = ""
    @State private var showTemplateSavedToast = false
    @State private var templateSaveError = false
    @State private var sourceTemplate: WorkoutTemplate?
    // The frozen prescription this resolved session fulfills (nil for template/blank sessions). Set on
    // load; used after a successful save to mark the prescription completed + link the session id.
    @State private var resolvedPrescriptionID: UUID?
    // Held (NOT a method local) to honor the @MainActor deinit-safety invariant: a @MainActor
    // repository deallocated mid-synchronous-method trips the iOS-26.1-sim back-deploy deinit SIGABRT.
    // Lazily created on the resolved-plan load path; used to mark the prescription completed on save.
    @State private var plannedSessionRepository: PlannedSessionRepository?
    // Zero-done save guard: true when Finish is tapped but NO set is marked done. Saving would
    // log an empty session, so Cancel keeps editing and Discard exits without persistence.
    @State private var showZeroDoneGuard = false

    private var athlete: Athlete? { athletes.first }

    /// Template / blank session path (unchanged). Never carries a resolved plan.
    init(template: WorkoutTemplate? = nil) {
        self.template = template
        self.resolvedPlan = nil
        let initialSport = template?.sportType ?? .lifting
        let initialSession = template?.sessionType ?? .strength
        _sportType = State(initialValue: initialSport)
        _sessionType = State(initialValue: initialSession)
        _sessionStartChoice = State(
            initialValue: SessionStartMapper.choice(
                sportType: initialSport,
                sessionType: initialSession
            )
        )
    }

    /// Verdict-resolved session path: launch the exact numbers an accepted/kept verdict produced.
    /// Mutually exclusive with the template path — `template` is forced nil so the two cannot combine.
    init(resolvedPlan: ResolvedSessionPlan) {
        self.template = nil
        self.resolvedPlan = resolvedPlan
        _sportType = State(initialValue: resolvedPlan.sportType)
        _sessionType = State(initialValue: resolvedPlan.sessionType)
        _sessionStartChoice = State(
            initialValue: SessionStartMapper.choice(
                sportType: resolvedPlan.sportType,
                sessionType: resolvedPlan.sessionType
            )
        )
    }

    var elapsed: TimeInterval {
        Date.now.timeIntervalSince(startTime)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Session info
                    VStack(spacing: 16) {
                        TextField(String(localized: "workout.field.sessionName.placeholder", defaultValue: "Session Name (optional)"), text: $sessionName)
                            .textFieldStyle(SharpTextFieldStyle())
                            .accessibilityIdentifier("activeWorkout.sessionName")

                        SessionStartPicker(
                            choice: $sessionStartChoice,
                            sportType: $sportType,
                            sessionType: $sessionType,
                            matchTier: $matchTier,
                            defaultSessionType: defaultSessionType(for:)
                        )

                        TimelineView(.periodic(from: startTime, by: 1)) { _ in
                            Text(Date.durationString(seconds: Int(elapsed), locale: locale))
                                .font(.Tokens.pageTitle)
                                .monospacedDigit()
                                .foregroundStyle(ColorTokens.text1)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(ColorTokens.surface)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    // Fill buttons (template-loaded sessions only)
                    if sourceTemplate != nil {
                        FillButtonBar(
                            entries: $entries,
                            isPro: container.subscriptionService.isPro
                        )
                        Rectangle()
                            .fill(ColorTokens.divider)
                            .frame(height: 0.5)
                    }

                    // Exercise entries
                    ForEach($entries) { $entry in
                        ExerciseEntryCard(entry: $entry, sportType: sportType, weightUnit: athlete?.weightUnit ?? .kg)
                        Rectangle()
                            .fill(ColorTokens.divider)
                            .frame(height: 0.5)
                    }
                    .onDelete { indexSet in
                        entries.remove(atOffsets: indexSet)
                    }

                    // Add exercise button
                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("action.addExercise", systemImage: "plus")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                    .background(ColorTokens.background)

                    // Duplicate the most-recently-added exercise as a fresh GHOST-scaffolded
                    // entry (§E.2): same name/category/muscle, set count carried, every value
                    // ghosted (isDone=false) so building a multi-exercise session is fast
                    // without re-picking — and nothing is logged until the user confirms.
                    if entries.last != nil {
                        Rectangle()
                            .fill(ColorTokens.divider)
                            .frame(height: 0.5)
                        Button(action: duplicateLastExercise) {
                            Label("action.duplicateExercise", systemImage: "plus.square.on.square")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                        .background(ColorTokens.background)
                    }
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("nav.workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.finish") { showFinishConfirmation = true }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text1)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(sportType: sportType) { name, category, muscle in
                    var draft = ExerciseEntryDraft(
                        exerciseName: name,
                        exerciseCategory: category,
                        muscleGroup: muscle
                    )
                    // Progressive overload suggestions are a Pro feature.
                    // Free tier falls back to raw last-session history.
                    if container.subscriptionService.isPro {
                        prefillFromHistory(&draft)
                    } else {
                        fallbackFromHistoryPublic(&draft)
                    }
                    entries.append(draft)
                }
            }
            .sheet(isPresented: $showFinishConfirmation) {
                FinishWorkoutSheet(
                    rpe: $sessionRPE,
                    saveAsTemplate: $saveAsTemplate,
                    templateName: $templateName,
                    sessionName: sessionName.isEmpty ? sportType.displayName : sessionName,
                    sportType: sportType,
                    onFinish: {
                        if saveAsTemplate {
                            saveAsTemplateFromSession()
                        }
                        saveSession()
                    }
                )
            }
            // Inline, non-blocking post-save banners (A.5). Both can show together when
            // a session sets a PR AND spikes load. The session is already committed before
            // either appears; tapping the last banner closes the workout sheet.
            .overlay(alignment: .bottom) {
                VStack(spacing: 8) {
                    if showPRCelebration {
                        PRBanner(prs: newPRs) {
                            showPRCelebration = false
                            advancePostSave()
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if showSpikeAlert, let spikeAlert {
                        SpikeAlertBanner(alert: spikeAlert) {
                            showSpikeAlert = false
                            advancePostSave()
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 16)
                .padding(.horizontal, 16)
            }
            .animation(Motion.entrance, value: showSpikeAlert)
            .animation(Motion.entrance, value: showPRCelebration)
            .overlay(alignment: .bottom) {
                if showTemplateSavedToast {
                    ToastBanner(
                        message: templateSaveError ? String(localized: "error.templateSave", defaultValue: "Couldn't save template. Try again.") : String(localized: "message.templateSaved", defaultValue: "Template saved"),
                        isError: templateSaveError,
                        isPresented: $showTemplateSavedToast
                    )
                    .padding(.bottom, 16)
                    .padding(.horizontal, 16)
                }
            }
            .animation(Motion.entrance, value: showTemplateSavedToast)
            // Zero-done save guard: Finish was tapped with NO set marked done. Saving now would
            // log an empty session, so Cancel keeps the user in the sheet and Discard exits
            // without persistence.
            .confirmationDialog(
                String(localized: "workout.save.noDone.title", defaultValue: "No sets marked done"),
                isPresented: $showZeroDoneGuard,
                titleVisibility: .visible
            ) {
                Button(String(localized: "workout.save.noDone.discard", defaultValue: "Discard session"), role: .destructive) {
                    dismiss()
                }
                Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "workout.save.noDone.message", defaultValue: "Nothing will be logged. Mark sets done to record them, or discard this session?"))
            }
            .onAppear {
                // Warm the haptic generators: this is the highest-interaction screen (per-set
                // done taps, weight/rep commits) so latency on the first tap matters.
                Haptics.prepare()
                if template != nil && entries.isEmpty {
                    loadFromTemplate()
                } else if let resolvedPlan, entries.isEmpty {
                    loadFromResolvedPlan(resolvedPlan)
                }
            }
        }
    }

    // MARK: - Smart Exercise Suggestions

    /// Pre-fill a draft using ProgressionEngine (recovery-aware progressive overload)
    /// Falls back to raw history if no recovery data is available.
    private func prefillFromHistory(_ draft: inout ExerciseEntryDraft) {
        let history = ProgressionEngine.fetchHistory(
            exerciseName: draft.exerciseName,
            modelContext: modelContext
        )

        guard !history.isEmpty else { return }

        // Build training context from current recovery state
        let context = buildTrainingContext()

        let suggestion = ProgressionEngine.suggest(
            exerciseName: draft.exerciseName,
            category: draft.exerciseCategory,
            context: context,
            recentEntries: history
        )

        guard !suggestion.suggestedSets.isEmpty else {
            // Fallback: just use last session's raw data
            fallbackFromHistory(&draft, history: history)
            return
        }

        // GHOST, not concrete (inverse data-loss fix): suggested values are PROVISIONAL —
        // they render ghosted and only become concrete (and isDone) when the user commits
        // (tap the weight tile / ± / keypad / done toggle). Leaving reps/weightKg = nil means
        // an untouched suggested set is not silently logged as performed.
        draft.sets = suggestion.suggestedSets.map { s in
            SetDraft(
                targetReps: s.reps,
                targetWeightKg: s.weightKg,
                targetRPE: s.rpe,
                targetDistanceMeters: s.distanceMeters,
                targetDurationSeconds: s.durationSeconds,
                isFromHistory: true
            )
        }
        draft.suggestionRationale = suggestion.rationale
        draft.progressionType = suggestion.progressionType
        stampLastSession(&draft, history: history)
    }

    /// Stamp the last-session NON-WARMUP fallback onto every set of a draft (Phase F, §3.3 #3).
    /// Resolves the single most-recent non-warmup candidate once from the already-fetched history
    /// and stashes it on the transient `SetDraft.lastSession*` fields. This is the precedence-3
    /// source: it does NOT overwrite template/in-session/progression values — `SetSuggestion`
    /// only falls through to it when nothing earlier in the ladder supplied a value. Stamping
    /// here (one read at add/open time) keeps it off the per-render path.
    private func stampLastSession(_ draft: inout ExerciseEntryDraft, history: [ExerciseHistoryRecord]) {
        guard let candidate = SetSuggestion.lastSessionCandidate(from: history) else { return }
        for i in draft.sets.indices {
            draft.sets[i].lastSessionWeightKg = candidate.weightKg
            draft.sets[i].lastSessionReps = candidate.reps
            draft.sets[i].lastSessionDistanceMeters = candidate.distanceMeters
            draft.sets[i].lastSessionDurationSeconds = candidate.durationSeconds
        }
    }

    /// Build training context from the latest recovery snapshot and workload data
    private func buildTrainingContext() -> ProgressionEngine.TrainingContext {
        // Try to fetch latest recovery snapshot
        let recoveryDescriptor = FetchDescriptor<RecoverySnapshot>(
            sortBy: [SortDescriptor(\RecoverySnapshot.date, order: .reverse)]
        )
        let latestRecovery = try? modelContext.fetch(recoveryDescriptor).first

        // Try to fetch latest workload snapshot
        let workloadDescriptor = FetchDescriptor<WorkloadSnapshot>(
            sortBy: [SortDescriptor(\WorkloadSnapshot.snapshotDate, order: .reverse)]
        )
        let latestWorkload = try? modelContext.fetch(workloadDescriptor).first

        let recoveryZone = latestRecovery.map { RecoveryZone.classify(score: $0.recoveryScore) } ?? .yellow
        let recoveryScore = latestRecovery?.recoveryScore ?? 50.0
        let acwrZone = latestWorkload.map { ACWRZone.classify(acwr: $0.acwr, ctl: $0.chronicLoad) } ?? .noData

        // Run AutoregulationEngine for volume/intensity caps
        let daysSinceRest = computeDaysSinceRest()
        let rec = AutoregulationEngine.recommend(input: .init(
            recoveryZone: recoveryZone,
            recoveryScore: recoveryScore,
            acwrZone: acwrZone,
            acwr: latestWorkload?.acwr ?? 0,
            wellnessScore: nil,
            daysSinceLastRest: daysSinceRest
        ))

        return ProgressionEngine.TrainingContext(
            recoveryZone: recoveryZone,
            recoveryScore: recoveryScore,
            volumeModifier: rec.volumeModifier,
            intensityCap: rec.intensityCap,
            acwrZone: acwrZone
        )
    }

    private func computeDaysSinceRest() -> Int {
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\WorkoutSession.sessionDate, order: .reverse)]
        )
        guard let sessions = try? modelContext.fetch(descriptor) else { return 0 }
        var consecutive = 0
        let calendar = Calendar.current
        var checkDate = calendar.startOfDay(for: .now)
        for session in sessions {
            let sessionDay = calendar.startOfDay(for: session.sessionDate)
            if sessionDay == checkDate || sessionDay == calendar.date(byAdding: .day, value: -1, to: checkDate) {
                consecutive += 1
                checkDate = sessionDay
            } else {
                break
            }
        }
        return consecutive
    }

    /// Free-tier fallback: fetch history and copy last session's sets (no overload logic).
    private func fallbackFromHistoryPublic(_ draft: inout ExerciseEntryDraft) {
        let history = ProgressionEngine.fetchHistory(
            exerciseName: draft.exerciseName,
            modelContext: modelContext
        )
        fallbackFromHistory(&draft, history: history)
    }

    /// Raw history fallback when ProgressionEngine has no suggestions
    private func fallbackFromHistory(_ draft: inout ExerciseEntryDraft, history: [ExerciseHistoryRecord]) {
        guard let last = history.first else { return }
        // GHOST, not concrete (inverse data-loss fix): last session's numbers render as
        // provisional suggestions; the user commits each set to log it.
        // Exclude warmup sets from the scaffold so the prefilled ghosts are working sets only
        // (warmups must not poison the suggested center — proposal §3.3 #3 / Phase F). If the
        // last session was ALL warmups, fall back to its sets so the grid isn't empty.
        let working = last.sets.filter { !$0.isWarmup }
        let source = working.isEmpty ? last.sets : working
        draft.sets = source.map { set in
            SetDraft(
                targetReps: set.reps,
                targetWeightKg: set.weightKg,
                targetRPE: set.rpe,
                targetDistanceMeters: set.distanceMeters,
                targetDurationSeconds: set.durationSeconds,
                isFromHistory: true
            )
        }
        stampLastSession(&draft, history: history)
    }

    /// Duplicate the most-recently-added exercise in THIS session as a new GHOST-scaffolded
    /// entry (§E.2). Reuses the existing add-exercise + ghost-prefill path: carries the same
    /// name/category/muscle, and rebuilds the set scaffold with every value as a ghost target
    /// (isDone=false). When no in-session source values exist it falls back to history prefill
    /// so the duplicate is never an empty grid. Ghosts only — never concrete — so the pipeline
    /// is not polluted until the user explicitly commits.
    private func duplicateLastExercise() {
        guard let source = entries.last else { return }

        var draft = ExerciseEntryDraft(
            exerciseName: source.exerciseName,
            exerciseCategory: source.exerciseCategory,
            muscleGroup: source.muscleGroup
        )
        draft.groupName = source.groupName

        // Rebuild the source's sets as ghosts: prefer the source set's committed value, fall
        // back to its own ghost target. Never copy isDone — a duplicate starts uncommitted.
        let ghostSets: [SetDraft] = source.sets.map { s in
            SetDraft(
                targetReps: s.reps ?? s.targetReps,
                targetWeightKg: s.weightKg ?? s.targetWeightKg,
                targetRPE: s.rpe ?? s.targetRPE,
                targetDistanceMeters: s.distanceMeters ?? s.targetDistanceMeters,
                targetDurationSeconds: s.durationSeconds ?? s.targetDurationSeconds,
                isFromHistory: true
            )
        }
        draft.sets = ghostSets.isEmpty ? [SetDraft()] : ghostSets

        // If the source carried no usable values at all, fall back to the same history
        // prefill the picker uses, keeping behavior consistent with adding via the picker.
        let allEmpty = ghostSets.allSatisfy { $0.targetReps == nil && $0.targetWeightKg == nil
            && $0.targetDistanceMeters == nil && $0.targetDurationSeconds == nil }
        if ghostSets.isEmpty || allEmpty {
            if container.subscriptionService.isPro {
                prefillFromHistory(&draft)
            } else {
                fallbackFromHistoryPublic(&draft)
            }
        }

        entries.append(draft)
    }

    private func defaultSessionType(for sport: SportType) -> SessionType {
        SessionStartMapper.defaultSessionType(
            for: sport,
            currentSessionType: sessionType
        )
    }

    // MARK: - Template Loading

    private func loadFromTemplate() {
        guard let tmpl = template else { return }
        sessionName = tmpl.templateName
        sportType = tmpl.sportType
        sessionType = tmpl.sessionType
        sessionStartChoice = SessionStartMapper.choice(
            sportType: tmpl.sportType,
            sessionType: tmpl.sessionType
        )
        sourceTemplate = tmpl

        let isPro = container.subscriptionService.isPro
        let context = isPro ? buildTrainingContext() : nil

        entries = tmpl.sortedGroups.flatMap { group in
            group.sortedExercises.map { exercise in
                var draft = ExerciseEntryDraft(
                    exerciseName: exercise.exerciseName,
                    exerciseCategory: exercise.exerciseCategory,
                    muscleGroup: exercise.muscleGroup
                )
                draft.groupName = group.groupName

                let history = ProgressionEngine.fetchHistory(
                    exerciseName: exercise.exerciseName,
                    modelContext: modelContext
                )

                if !history.isEmpty, let lastEntry = history.first {
                    // Ghost targets from last session actuals
                    draft.sets = exercise.sortedSets.enumerated().map { idx, templateSet in
                        let historySet = idx < lastEntry.sets.count ? lastEntry.sets[idx] : nil
                        return SetDraft(
                            targetReps: historySet?.reps ?? templateSet.targetReps,
                            targetWeightKg: historySet?.weightKg ?? templateSet.targetWeightKg,
                            targetRPE: historySet?.rpe ?? templateSet.targetRPE,
                            targetRIR: templateSet.targetRIR,   // history records carry no RIR; use the authored target
                            isFromHistory: true
                        )
                    }
                    // Add extra sets from history if template has fewer
                    if lastEntry.sets.count > exercise.sortedSets.count {
                        for idx in exercise.sortedSets.count..<lastEntry.sets.count {
                            let historySet = lastEntry.sets[idx]
                            draft.sets.append(SetDraft(
                                targetReps: historySet.reps,
                                targetWeightKg: historySet.weightKg,
                                targetRPE: historySet.rpe,
                                isFromHistory: true
                            ))
                        }
                    }

                    // Pro users get ProgressionEngine suggestions
                    if isPro, let ctx = context {
                        let suggestion = ProgressionEngine.suggest(
                            exerciseName: exercise.exerciseName,
                            category: exercise.exerciseCategory,
                            context: ctx,
                            recentEntries: history
                        )
                        draft.suggestionRationale = suggestion.rationale
                        draft.progressionType = suggestion.progressionType
                        if !suggestion.suggestedSets.isEmpty {
                            draft.progressionSuggestions = suggestion.suggestedSets
                        }
                    }
                } else {
                    // No history: use template defaults as ghost targets
                    draft.sets = exercise.sortedSets.map { templateSet in
                        SetDraft(
                            targetReps: templateSet.targetReps,
                            targetWeightKg: templateSet.targetWeightKg,
                            targetRPE: templateSet.targetRPE,
                            targetRIR: templateSet.targetRIR,
                            isFromHistory: false
                        )
                    }
                }

                if draft.sets.isEmpty { draft.sets = [SetDraft()] }
                // Stash last-session non-warmup fallback (precedence 3) so a templated set with
                // no per-set target still centers on the most-recent working set (Phase F).
                stampLastSession(&draft, history: history)
                return draft
            }
        }
    }

    // MARK: - Resolved-Plan Loading (verdict → workout)

    /// Populate drafts DIRECTLY from a verdict-resolved plan. Deliberately bypasses everything the
    /// template path overlays: NO `ProgressionEngine`, NO history fetch, NO template-target fallback —
    /// the resolved numbers ARE the targets. `sourceTemplate` stays nil so the FillButtonBar is hidden
    /// and usage stats aren't bumped. Sets render as ghosts (isDone=false) so the zero-done guard still
    /// protects the prefilled work; reps/RPE/distance/duration and warm-up status are preserved.
    private func loadFromResolvedPlan(_ plan: ResolvedSessionPlan) {
        sessionName = plan.sessionName
        sportType = plan.sportType
        sessionType = plan.sessionType
        sessionStartChoice = SessionStartMapper.choice(
            sportType: plan.sportType,
            sessionType: plan.sessionType
        )
        resolvedPrescriptionID = plan.prescriptionID
        // Own the repository for the sheet's lifetime (deinit-safety invariant — see property note).
        if plannedSessionRepository == nil {
            plannedSessionRepository = PlannedSessionRepository(modelContext: modelContext)
        }

        entries = plan.exercises.map { exercise in
            var draft = ExerciseEntryDraft(
                exerciseName: exercise.exerciseName,
                exerciseCategory: exercise.exerciseCategory,
                muscleGroup: exercise.muscleGroup
            )
            draft.groupName = exercise.groupName
            draft.sets = exercise.sets.map { set in
                var setDraft = SetDraft(
                    targetReps: set.reps,
                    targetWeightKg: set.weightKg,
                    targetRPE: set.rpe,
                    targetDistanceMeters: set.distanceMeters,
                    targetDurationSeconds: set.durationSeconds,
                    isFromHistory: false
                )
                setDraft.isWarmup = set.isWarmup
                setDraft.targetRIR = set.rir   // planned RIR as a GHOST target (never an achieved value)
                setDraft.plannedWeightKg = set.plannedWeightKg
                setDraft.plannedRPE = set.plannedRPE
                setDraft.isSuggestedAdjustment = set.isSuggestedAdjustment
                setDraft.verdictReason = set.verdictReason
                return setDraft
            }
            if draft.sets.isEmpty { draft.sets = [SetDraft()] }
            return draft
        }
    }

    // MARK: - Save

    /// Total sets the user has actually committed across all exercises.
    private var doneSetCount: Int {
        entries.reduce(0) { $0 + $1.sets.filter { $0.isDone }.count }
    }

    private func saveSession() {
        // Warm the haptic generators ahead of the imminent save-commit feedback.
        Haptics.prepare()
        // Zero-done guard: do NOT silently save an empty session. If at least one set is done,
        // partial saves proceed normally.
        if doneSetCount == 0 {
            showZeroDoneGuard = true
            return
        }
        persistSession()
    }

    private func persistSession() {
        let session = WorkoutSession(
            sessionDate: startTime,
            sessionName: sessionName.isEmpty ? nil : sessionName,
            sportType: sportType,
            durationSeconds: Int(elapsed),
            sessionRPE: sessionRPE,
            sessionType: sessionType
        )

        var entryOrder = 0
        for draft in entries {
            // Persist ONLY sets the user actually performed (proposal §13, Option A): untouched
            // prefilled / ghost / carried template sets default isDone == false and must
            // not pollute PR / volume / history / progression. A done warmup still saves as warmup.
            let doneSets = draft.sets.filter { $0.isDone }
            guard !doneSets.isEmpty else { continue }

            let entry = ExerciseEntry(
                exerciseName: draft.exerciseName,
                exerciseCategory: draft.exerciseCategory,
                muscleGroup: draft.muscleGroup,
                orderIndex: entryOrder
            )
            entryOrder += 1

            for (setIdx, setDraft) in doneSets.enumerated() {
                let setRecord = SetRecord(
                    setIndex: setIdx,
                    reps: setDraft.reps,
                    weightKg: setDraft.weightKg,
                    durationSeconds: setDraft.durationSeconds,
                    distanceMeters: setDraft.distanceMeters,
                    rpe: setDraft.rpe,
                    rir: setDraft.rir,
                    isWarmup: setDraft.isWarmup
                )
                entry.sets.append(setRecord)
            }

            session.exerciseEntries.append(entry)
        }

        session.recalculateDerivedFields()
        // Match tier (v2.1 beachhead): recorded only for match-type sessions. An untouched
        // picker persists .pickup EXPLICITLY — the picker showed Pickup as the effective
        // selection, so the saved row records "true pickup" instead of conflating it with
        // "unknown" (pre-v2.1 rows keep nil = genuinely unknown).
        session.matchTier = MatchTier.persistedTier(sessionType: sessionType, selected: matchTier)
        session.sourceTemplateId = sourceTemplate?.id
        session.athlete = athlete
        modelContext.insert(session)

        do {
            try modelContext.save()
        } catch {
            print("Failed to save session: \(error)")
            dismiss()
            return
        }

        // Verdict → workout linkage (only reached AFTER a successful save): this session fulfills the
        // resolved prescription, so mark it completed and link the saved session id. Closes the loop
        // (prescription.completedSessionId) and makes verdict→prescription→session queryable. Never
        // runs for template/blank sessions (resolvedPrescriptionID stays nil) and never on save failure.
        if let prescriptionID = resolvedPrescriptionID {
            // Use the held repository (deinit-safety); fall back to a fresh one only if the load path
            // never ran (shouldn't happen on the resolved path that sets resolvedPrescriptionID).
            let repo = plannedSessionRepository ?? PlannedSessionRepository(modelContext: modelContext)
            let linked = repo.markCompleted(prescriptionId: prescriptionID, completedSessionId: session.id)
            if !linked {
                // The session IS saved; only the prescription link failed. Do NOT delete the session —
                // leave the prescription assigned so it stays recoverable (relink by id later). Surface
                // the failure rather than swallowing it.
                print("Verdict linkage failed: session \(session.id) saved but prescription \(prescriptionID) not marked completed.")
            }
        }

        // Update template usage stats
        if let source = sourceTemplate {
            source.lastUsedAt = .now
            source.usageCount += 1
            source.updatedAt = .now
            try? modelContext.save()
        }

        if let athlete {
            do {
                let result = try WorkoutPipeline.processSession(
                    session,
                    athlete: athlete,
                    modelContext: modelContext,
                    syncService: container.syncService
                )

                if let spike = result.spikeAlert {
                    spikeAlert = spike
                    showSpikeAlert = true
                }

                if !result.newPRs.isEmpty {
                    newPRs = result.newPRs
                    showPRCelebration = true
                }

                // Commit-only haptics (single, outcome-based — no stacking): a surfaced spike
                // is the dominant signal → warning; a PR with no spike → success. The plain
                // "saved" success for the no-banner case fires at finishAfterSave below.
                if showSpikeAlert {
                    Haptics.warning()
                } else if showPRCelebration {
                    Haptics.success()
                }

                // Inline banners fired — the save is ALREADY committed above. Let the
                // bottom banner stack render and stop here; the sheet stays open but is
                // NOT blocked (user can still dismiss). advancePostSave() runs when the
                // last banner is tapped away.
                if showPRCelebration || showSpikeAlert { return }
            } catch {
                print("Workout pipeline error: \(error)")
            }
        }

        // No PR/spike branch fired; the save is already committed above. Fire the single
        // "session saved" success haptic, then close the sheet.
        Haptics.success()
        finishAfterSave()
    }

    /// Bridge from banner dismissal to the terminal post-save flow. The session is ALREADY
    /// committed by the time any banner shows. Only advance once BOTH inline banners are
    /// dismissed so the PR/spike branches resolve before the sheet closes.
    private func advancePostSave() {
        guard !showPRCelebration, !showSpikeAlert else { return }
        finishAfterSave()
    }

    /// Terminal exit for the post-save flow. The session is already saved by the time this runs.
    private func finishAfterSave() {
        dismiss()
    }

    // MARK: - Save as Template

    private func saveAsTemplateFromSession() {
        guard let athleteId = athlete?.id else { return }
        let name = templateName.isEmpty ? (sessionName.isEmpty ? sportType.displayName : sessionName) : templateName

        let template = WorkoutTemplate(
            coachId: athleteId,
            templateName: name,
            sportType: sportType,
            sessionType: sessionType
        )
        template.isAthleteOwned = true
        template.athleteId = athleteId

        // All exercises in one "Main" group per TMPL-02
        let group = ExerciseGroup(groupName: "Main", orderIndex: 0)
        for (idx, entry) in entries.enumerated() {
            // Skip entries with no valid sets (per RESEARCH.md Pitfall 5)
            let validSets = entry.sets.filter { s in
                s.reps != nil || s.weightKg != nil || s.durationSeconds != nil || s.distanceMeters != nil
            }
            guard !validSets.isEmpty else { continue }

            let exercise = TemplateExercise(
                exerciseName: entry.exerciseName,
                exerciseCategory: entry.exerciseCategory,
                muscleGroup: entry.muscleGroup,
                orderIndex: idx
            )
            for (sIdx, set) in validSets.enumerated() {
                let targetSet = TemplateSet(
                    setIndex: sIdx,
                    targetReps: set.reps,
                    targetWeightKg: set.weightKg,
                    targetRPE: set.rpe,
                    targetRIR: set.rir,
                    isWarmup: set.isWarmup
                )
                exercise.sets.append(targetSet)
            }
            group.exercises.append(exercise)
        }
        template.groups.append(group)

        modelContext.insert(template)
        do {
            try modelContext.save()
            showTemplateSavedToast = true
            templateSaveError = false
            Task {
                await container.syncService.pushWorkoutTemplates(context: modelContext, coachId: athleteId)
            }
        } catch {
            print("Failed to save template: \(error)")
            showTemplateSavedToast = true
            templateSaveError = true
        }
    }
}

// MARK: - Exercise Entry Card

struct ExerciseEntryCard: View {
    @Binding var entry: ExerciseEntryDraft
    var sportType: SportType = .lifting
    var weightUnit: WeightUnit = .kg

    private var inputMode: ExerciseInputMode {
        entry.exerciseCategory.inputMode
    }

    /// Append a new set that carries forward the previous set's values onto the GHOST-target
    /// fields (targetWeightKg/targetReps/targetRPE and the cardio targetDistance/targetDuration)
    /// so the new row renders them ghosted without marking them committed — a ± tap, keypad edit,
    /// or done toggle commits them. This keeps carry-forward consistent with the ghost/commit
    /// model across BOTH weight/reps and cardio, so a carried set is never silently logged as
    /// performed until the user confirms it.
    private func addCarriedSet() {
        var draft = SetDraft()
        if let last = entry.sets.last {
            draft.targetWeightKg = last.weightKg ?? last.targetWeightKg
            draft.targetReps = last.reps ?? last.targetReps
            draft.targetRPE = last.rpe ?? last.targetRPE
            draft.targetDistanceMeters = last.distanceMeters ?? last.targetDistanceMeters
            draft.targetDurationSeconds = last.durationSeconds ?? last.targetDurationSeconds
        }
        entry.sets.append(draft)
    }

    /// Clone the previous set entirely as committed (real) values — the "Repeat last set" path.
    private func repeatLastSet() {
        guard let last = entry.sets.last else { return }
        var clone = SetDraft()
        clone.reps = last.reps ?? last.targetReps
        clone.weightKg = last.weightKg ?? last.targetWeightKg
        clone.durationSeconds = last.durationSeconds
        clone.distanceMeters = last.distanceMeters
        clone.rpe = last.rpe
        clone.rir = last.rir
        clone.isWarmup = last.isWarmup
        // Explicit user action ("repeat this set, it counts") → the clone is performed.
        // (addCarriedSet's passive ghost prefill leaves isDone == false on purpose.)
        clone.isDone = true
        entry.sets.append(clone)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(entry.exerciseName)
                    .font(.Tokens.sectionHead)
                    .foregroundStyle(ColorTokens.text1)
                Spacer()
                if let muscle = entry.muscleGroup {
                    Text(muscle.displayName)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)

            // Suggestion rationale
            if let rationale = entry.suggestionRationale {
                Text(rationale)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            } else if entry.sets.first?.isFromHistory == true {
                Text("exercise.label.prefilledFromLast")
                    .font(.Tokens.micro)
                    .tracking(1.0)
                    .foregroundStyle(ColorTokens.text3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)

            // Column headers based on input mode. RPE is no longer a fixed column — it lives
            // behind a per-row "+ RPE" chip (fast path = weight + reps only).
            switch inputMode {
            case .weightReps:
                setHeaderRow(columns: [("table.header.set", 32), ("table.header.weight", 0), ("table.header.reps", 0)])
            case .repsOnly:
                setHeaderRow(columns: [("table.header.set", 32), ("table.header.reps", 0)])
            case .distanceDuration:
                setHeaderRow(columns: [("table.header.set", 32), ("table.header.dist", 0), ("table.header.time", 0)])
            case .durationOnly:
                setHeaderRow(columns: [("table.header.set", 32), ("table.header.timeMin", 0)])
            }

            ForEach($entry.sets) { $set in
                let setIndex = entry.sets.firstIndex(where: { $0.id == set.id }) ?? 0
                VStack(spacing: 0) {
                    SetEntryRow(
                        set: $set,
                        index: setIndex,
                        inputMode: inputMode,
                        weightUnit: weightUnit,
                        exerciseName: entry.exerciseName,
                        category: entry.exerciseCategory,
                        suggestion: entry.progressionSuggestions.flatMap { suggestions in
                            setIndex < suggestions.count ? suggestions[setIndex] : nil
                        },
                        progressionType: entry.progressionType,
                        showSuggestion: entry.progressionSuggestions != nil
                    )
                }
                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
            }

            // Repeat last set — clones the prior set entirely (committed values).
            if !entry.sets.isEmpty {
                Button(action: repeatLastSet) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "arrow.clockwise")
                            .font(.Tokens.label)
                        Text("set.action.repeatLast")
                            .font(.Tokens.label)
                    }
                    .foregroundStyle(ColorTokens.text1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .contentShape(Rectangle())
                    .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
                }
                .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                .padding(.horizontal, Spacing.sm)
                .padding(.top, Spacing.xs)
            }

            // Add set — dashed affordance carrying forward the previous set (ghosted).
            Button(action: addCarriedSet) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "plus")
                        .font(.Tokens.label)
                    Text("set.action.add")
                        .font(.Tokens.label)
                }
                .foregroundStyle(ColorTokens.text2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .contentShape(Rectangle())
                .overlay(
                    Rectangle()
                        .stroke(ColorTokens.divider, style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                )
            }
            .buttonStyle(.pressable(scale: 1, opacity: 0.6))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
        }
        .background(ColorTokens.surfaceEl)
    }

    private func setHeaderRow(columns: [(LocalizedStringKey, CGFloat)]) -> some View {
        HStack {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, col in
                if col.1 > 0 {
                    Text(col.0).frame(width: col.1)
                } else {
                    Text(col.0).frame(maxWidth: .infinity)
                }
            }
        }
        .font(.Tokens.micro)
        .tracking(1.2)
        .foregroundStyle(ColorTokens.text3)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Set Entry Row

struct SetEntryRow: View {
    @Binding var set: SetDraft
    let index: Int
    var inputMode: ExerciseInputMode = .weightReps
    var weightUnit: WeightUnit = .kg
    /// Exercise identity for the suggestion read (Phase F). Drives the category-neutral reps
    /// fallback correctly (v1 hardcoded `.compound`) and is passed to `SetSuggestion` for
    /// documentation symmetry. Not used to fetch — pure presentation.
    var exerciseName: String = ""
    var category: ExerciseCategory = .compound
    var suggestion: ProgressionEngine.SetSuggestion? = nil
    var progressionType: ProgressionEngine.ProgressionType? = nil
    var showSuggestion: Bool = false

    /// Per-set RPE is collapsed behind a "+ RPE" chip; start expanded only if RPE already set.
    @State private var showRPE = false

    /// Shared inline-keypad focus for this row's weight + reps fields, so a weight keypad
    /// commit advances to reps without dismissing/re-summoning the keyboard (§5.5).
    @FocusState private var focusField: SetFocusField?

    /// Local override controlling whether a completed (isDone) set shows its full editable
    /// row or the compact one-line summary (§5.3). nil = follow the default (collapse when
    /// done); true/false = the user's explicit tap to expand/collapse.
    @State private var expandOverride: Bool? = nil

    /// Whether the row is rendered collapsed: a done set collapses by default, but a user
    /// tap can force it open (or re-collapse it). Never collapse a not-done set.
    private var isCollapsed: Bool {
        guard set.isDone else { return false }
        return expandOverride == nil ? true : !(expandOverride!)
    }

    /// Weight ± step in the USER'S DISPLAY UNIT (not kg). Unit-aware: lb athletes nudge by
    /// 5 lb, kg athletes by 2.5 kg. The stepper now operates entirely in display units via
    /// `displayWeightBinding`, so the increment must also be a display-unit value.
    private var weightIncrementDisplay: Double {
        switch weightUnit {
        case .kg: return 2.5
        case .lbs: return 5
        }
    }

    /// Bridges the stored-kg `set.weightKg` to the field's DISPLAY unit. Reads convert
    /// kg → display unit; writes convert the typed display value back to kg for storage.
    /// nil (empty field) is preserved in both directions so an empty set stays empty.
    private var displayWeightBinding: Binding<Double?> {
        Binding(
            get: { set.weightKg.map { WeightFormatter.displayValue($0, unit: weightUnit) } },
            set: { newDisplay in
                set.weightKg = newDisplay.map { WeightFormatter.toKg($0, from: weightUnit) }
            }
        )
    }

    private var weightPlaceholder: String {
        switch weightUnit {
        case .kg: return "kg"
        case .lbs: return "lb"
        }
    }

    private var suggestionText: String? {
        guard showSuggestion, let s = suggestion, let weight = s.weightKg else { return nil }
        let formatted = String(format: "%.1f", weight)
        switch progressionType {
        case .increase:
            return String(format: String(localized: "set.suggestion.increase", defaultValue: "%@kg suggested"), formatted)
        case .maintain, .deload, .returnFromBreak, .none:
            return String(format: String(localized: "set.suggestion.maintain", defaultValue: "maintain %@kg"), formatted)
        }
    }

    private var suggestionIcon: String {
        switch progressionType {
        case .increase: return "arrow.up"
        default: return "arrow.right"
        }
    }

    /// Collapsed "+ RPE" chip → inline RPE stepper. Fast path never requires RPE.
    @ViewBuilder private var rpeControl: some View {
        if showRPE || set.rpe != nil {
            SetStepperDouble(
                value: $set.rpe,
                increment: 1,
                placeholder: "RPE",
                ghostBaseline: set.targetRPE,
                floor: 0,
                fractionDigits: 0
            )
            .frame(width: 120)
        } else {
            Button {
                showRPE = true
            } label: {
                Text("set.rpe.add")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xs)
                    .contentShape(Rectangle())
                    .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
            }
            .buttonStyle(.pressable)
        }
    }

    /// The effort control for the row — RPE-FIRST, deterministic precedence: a set whose authored
    /// effort target is RIR (planned RIR present, NO planned RPE) shows the RIR stepper; every other
    /// set keeps the existing RPE control unchanged. Never two competing primary controls.
    @ViewBuilder private var effortControl: some View {
        if set.targetRIR != nil && set.targetRPE == nil {
            rirControl
        } else {
            rpeControl
        }
    }

    /// Inline RIR stepper for RIR-authored sets. Ghosts the planned `targetRIR` (in `text3`) until the
    /// athlete commits a value via ± / keypad — so a prescribed RIR is shown as a TARGET and never
    /// auto-recorded as achieved. A committed value lands in `set.rir`, which saves to `SetRecord.rir`.
    @ViewBuilder private var rirControl: some View {
        SetStepperInt(
            value: $set.rir,
            increment: 1,
            placeholder: "RIR",
            ghostBaseline: set.targetRIR,
            floor: 0
        )
        .frame(width: 120)
    }

    /// Per-set DONE toggle (proposal §13, Option A). A square `Rectangle` checkbox: empty when
    /// not done, filled `text1` with a checkmark glyph when done. 0pt corners, 0.5pt hairline
    /// `divider` border, NO accent. ≥44pt touch target at the trailing end of the row. Tapping
    /// toggles `set.isDone`, controlling whether this set is persisted by saveSession().
    @ViewBuilder private var doneToggle: some View {
        Button {
            set.isDone.toggle()
            // Commit feedback only on the transition INTO done (the most-repeated commit).
            if set.isDone { Haptics.tap() }
        } label: {
            ZStack {
                Rectangle()
                    .fill(set.isDone ? ColorTokens.text1 : Color.clear)
                    .frame(width: 24, height: 24)
                    .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
                if set.isDone {
                    Image(systemName: "checkmark")
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.surface)
                }
            }
            // Settle the fill/checkmark in instead of popping it.
            .animation(Motion.state, value: set.isDone)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(set.isDone
            ? String(localized: "set.action.done", defaultValue: "Set done")
            : String(localized: "set.action.markDone", defaultValue: "Mark set done"))
        .accessibilityAddTraits(set.isDone ? [.isButton, .isSelected] : .isButton)
    }

    /// Per-set WARMUP toggle (§E.4 clarity). A clearly labeled, bordered control — never
    /// color-alone: the word "Warmup" plus a checkbox-style square communicate state. 0pt
    /// corners, 0.5pt hairline `divider`, NO accent. Warmups are still excluded from the
    /// suggestion source + PR by the existing logic; this only makes the flag visible/legible.
    @ViewBuilder private var warmupToggle: some View {
        Button {
            set.isWarmup.toggle()
        } label: {
            HStack(spacing: Spacing.baselinePair) {
                Rectangle()
                    .fill(set.isWarmup ? ColorTokens.text2 : Color.clear)
                    .frame(width: 12, height: 12)
                    .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
                Text("set.warmup.label")
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(set.isWarmup ? ColorTokens.text1 : ColorTokens.text2)
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.baselinePair)
            .contentShape(Rectangle())
            .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(String(localized: "set.warmup.label", defaultValue: "Warmup"))
        .accessibilityValue(set.isWarmup
            ? String(localized: "set.warmup.on", defaultValue: "On")
            : String(localized: "set.warmup.off", defaultValue: "Off"))
        .accessibilityAddTraits(set.isWarmup ? [.isButton, .isSelected] : .isButton)
    }

    /// Compact one-line summary of a completed set (§5.3). Tapping re-expands the full
    /// editable row (the set stays isDone). `text2`, monospacedDigit, 0pt/hairline, no accent.
    @ViewBuilder private var collapsedSummary: some View {
        Button {
            expandOverride = true
        } label: {
            HStack(spacing: Spacing.xs) {
                Text("\(index + 1)")
                    .frame(width: 32, alignment: .leading)
                    .font(.Tokens.label)
                    .foregroundStyle(set.isWarmup ? ColorTokens.zoneCaution : ColorTokens.text2)
                Text(summaryText)
                    .font(.Tokens.body)
                    .monospacedDigit()
                    .foregroundStyle(ColorTokens.text2)
                if set.isWarmup {
                    Text("set.warmup.label")
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text3)
                }
                Spacer()
                Image(systemName: "checkmark")
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
        .accessibilityElement(children: .combine)
        .accessibilityHint(String(localized: "set.collapsed.expandHint", defaultValue: "Tap to edit this set"))
    }

    /// One-line summary string for a completed set, e.g. "60kg × 5" / "12 reps" / "5km".
    /// Localized via composed format strings; numerals stay monospacedDigit at the call site.
    private var summaryText: String {
        switch inputMode {
        case .weightReps:
            let reps = set.reps ?? set.targetReps ?? 0
            if let kg = set.weightKg {
                let display = WeightFormatter.displayValue(kg, unit: weightUnit)
                let unit = weightUnit == .kg
                    ? String(localized: "unit.kg", defaultValue: "kg")
                    : String(localized: "unit.lb", defaultValue: "lb")
                let w = display == display.rounded() ? String(format: "%.0f", display) : String(format: "%.1f", display)
                return String(format: String(localized: "set.summary.weightReps", defaultValue: "%@%@ × %d"), w, unit, reps)
            }
            return String(format: String(localized: "set.summary.repsOnly", defaultValue: "%d reps"), reps)
        case .repsOnly:
            return String(format: String(localized: "set.summary.repsOnly", defaultValue: "%d reps"), set.reps ?? 0)
        case .distanceDuration:
            let dist = set.distanceMeters ?? 0
            let dur = set.durationSeconds ?? 0
            return String(format: String(localized: "set.summary.distDur", defaultValue: "%dm · %ds"), Int(dist), dur)
        case .durationOnly:
            return String(format: String(localized: "set.summary.dur", defaultValue: "%ds"), set.durationSeconds ?? 0)
        }
    }

    /// Suggested center weight (KG) for the WeightBlockPicker when this set has no committed
    /// weight yet. Resolved from already-available draft data via the pure `SetSuggestion`
    /// helper: ghost target (template / last-session prefill) → in-memory progression
    /// suggestion (Pro). No fetch, no engine call. nil → cold-start "—".
    private var suggestedCenterKg: Double? {
        let result = SetSuggestion.suggest(
            inputMode: inputMode,
            exerciseName: exerciseName,
            category: category,
            templateTarget: set.targetWeightKg.map { SetSuggestion.Candidate(weightKg: $0) },
            inSessionPrevSet: nil,
            lastSessionSet: lastSessionCandidate,
            isPro: suggestion != nil,
            progressionSuggestion: suggestion?.weightKg.map { SetSuggestion.Candidate(weightKg: $0) }
        )
        return result.centerWeightKg
    }

    /// Precedence-3 candidate built from the loader-stamped last-session NON-WARMUP fields
    /// (Phase F, §3.3 #3). nil when there's no non-warmup history → truly-first-ever stays "—".
    private var lastSessionCandidate: SetSuggestion.Candidate? {
        let candidate = SetSuggestion.Candidate(
            weightKg: set.lastSessionWeightKg,
            reps: set.lastSessionReps,
            distanceMeters: set.lastSessionDistanceMeters,
            durationSeconds: set.lastSessionDurationSeconds
        )
        return candidate.isEmpty ? nil : candidate
    }

    /// Suggested reps for the RepScrubber ghost baseline when this set has no committed reps.
    /// Same pure-presentation read as `suggestedCenterKg`: ghost target (template / last-session
    /// prefill) → in-memory progression suggestion (Pro) → category neutral default. No fetch,
    /// no engine call. The scrubber renders this in `text3` until the user commits.
    private var suggestedReps: Int? {
        let result = SetSuggestion.suggest(
            inputMode: inputMode,
            exerciseName: exerciseName,
            category: category,
            templateTarget: set.targetReps.map { SetSuggestion.Candidate(reps: $0) },
            inSessionPrevSet: nil,
            lastSessionSet: lastSessionCandidate,
            isPro: suggestion != nil,
            progressionSuggestion: suggestion?.reps.map { SetSuggestion.Candidate(reps: $0) }
        )
        return result.reps
    }

    /// Cardio measurement field with ghosted carried/target baseline (Double — distance).
    /// Mirrors SetStepper's ghost model: while `value == nil` and a ghost exists, the ghost
    /// renders in `text3` behind the empty field; a keypad edit commits it to `value` (which
    /// flips `isDone` via the row's .onChange). Untouched ghosts are never logged as performed.
    @ViewBuilder
    private func ghostedField(value: Binding<Double?>, ghost: Double?, placeholder: String, decimal: Bool) -> some View {
        let isGhost = value.wrappedValue == nil && ghost != nil
        ZStack {
            if isGhost, let g = ghost {
                Text(String(format: "%.0f", g))
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text3)
                    .monospacedDigit()
                    .allowsHitTesting(false)
            }
            TextField(isGhost ? "" : placeholder, value: value, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(SharpTextFieldStyle())
        }
        .frame(maxWidth: .infinity)
    }

    /// Cardio measurement field with ghosted carried/target baseline (Int — duration).
    @ViewBuilder
    private func ghostedField(value: Binding<Int?>, ghost: Int?, placeholder: String) -> some View {
        let isGhost = value.wrappedValue == nil && ghost != nil
        ZStack {
            if isGhost, let g = ghost {
                Text("\(g)")
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text3)
                    .monospacedDigit()
                    .allowsHitTesting(false)
            }
            TextField(isGhost ? "" : placeholder, value: value, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(SharpTextFieldStyle())
        }
        .frame(maxWidth: .infinity)
    }

    /// The set-number + measurement controls for the .weightReps row, laid out horizontally
    /// (default) or stacked vertically (Dynamic Type fallback so 3 tiles + reps + RPE + done
    /// never clip at AX sizes).
    @ViewBuilder private var weightRepsControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Spacing.xs) {
                weightRepsCore
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                weightRepsCore
            }
        }
    }

    @ViewBuilder private var weightRepsCore: some View {
        WeightBlockPicker(
            weightKg: $set.weightKg,
            unit: weightUnit,
            suggestedCenterKg: suggestedCenterKg,
            onCommit: { set.isDone = true },
            focus: $focusField,
            rowId: set.id,
            advanceTo: .reps(set.id)
        )
        RepScrubber(
            reps: $set.reps,
            suggestedReps: suggestedReps,
            onCommit: { set.isDone = true },
            focus: $focusField,
            rowId: set.id
        )
        effortControl
        doneToggle
    }

    var body: some View {
        if isCollapsed {
            collapsedSummary
        } else {
            expandedRow
        }
    }

    @ViewBuilder private var expandedRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                switch inputMode {
                case .weightReps:
                    HStack(alignment: .top, spacing: Spacing.xs) {
                        Text("\(index + 1)")
                            .frame(width: 32)
                            .font(.Tokens.label)
                            .foregroundStyle(set.isWarmup ? ColorTokens.zoneCaution : ColorTokens.text2)
                            .padding(.top, Spacing.xs)
                        weightRepsControls
                    }

                default:
                    HStack(spacing: Spacing.xs) {
                        Text("\(index + 1)")
                            .frame(width: 32)
                            .font(.Tokens.label)
                            .foregroundStyle(set.isWarmup ? ColorTokens.zoneCaution : ColorTokens.text2)

                        switch inputMode {
                        case .repsOnly:
                            SetStepperInt(
                                value: $set.reps,
                                increment: 1,
                                placeholder: "reps",
                                ghostBaseline: set.targetReps
                            )

                        case .distanceDuration:
                            ghostedField(value: $set.distanceMeters, ghost: set.targetDistanceMeters, placeholder: "m", decimal: true)
                            ghostedField(value: $set.durationSeconds, ghost: set.targetDurationSeconds, placeholder: "sec")

                        case .durationOnly:
                            ghostedField(value: $set.durationSeconds, ghost: set.targetDurationSeconds, placeholder: "min")

                        case .weightReps:
                            EmptyView()
                        }

                        effortControl

                        doneToggle
                    }
                }
            }
            .font(.Tokens.label)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            // Auto-mark performed when the user actually commits a measurement value. Prefill /
            // ghost / carry writes happen before this row renders (in onAppear loaders /
            // addCarriedSet), so their initial values do NOT trigger these onChange handlers —
            // only subsequent in-row user edits do. nil → some transition = a real entry.
            .onChange(of: set.weightKg) { _, newValue in if newValue != nil { set.isDone = true } }
            .onChange(of: set.reps) { _, newValue in if newValue != nil { set.isDone = true } }
            .onChange(of: set.durationSeconds) { _, newValue in if newValue != nil { set.isDone = true } }
            .onChange(of: set.distanceMeters) { _, newValue in if newValue != nil { set.isDone = true } }

            // Warmup toggle — visible, labeled, state-bearing (not color-alone). Aligned past
            // the set-number column so it reads as a per-set attribute.
            HStack(spacing: Spacing.xs) {
                warmupToggle
                Spacer()
            }
            .padding(.leading, 16 + 32 + Spacing.xs)
            .padding(.trailing, 16)
            .padding(.bottom, Spacing.xs)

            // Progression suggestion label (Pro users only)
            if let text = suggestionText {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: suggestionIcon)
                        .imageScale(.small)
                    Text(text)
                }
                .font(.Tokens.label)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xs)
                .accessibilityLabel(String(format: String(localized: "set.suggestion.accessibility", defaultValue: "Suggested: %@"), text))
            }
        }
    }
}

// MARK: - Fill Button Bar

struct FillButtonBar: View {
    @Binding var entries: [ExerciseEntryDraft]
    let isPro: Bool

    var body: some View {
        HStack(spacing: 16) {
            Button {
                fillLast()
            } label: {
                Text("workout.fill.last")
                    .font(.Tokens.bodyMedium)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
            }
            .buttonStyle(.pressable)

            if isPro {
                Button {
                    fillSuggested()
                } label: {
                    Text("workout.fill.suggested")
                        .font(.Tokens.bodyMedium)
                        .foregroundStyle(ColorTokens.text1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
                }
                .buttonStyle(.pressable)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surface)
    }

    private func fillLast() {
        for i in entries.indices {
            for j in entries[i].sets.indices {
                if entries[i].sets[j].reps == nil, let target = entries[i].sets[j].targetReps {
                    entries[i].sets[j].reps = target
                }
                if entries[i].sets[j].weightKg == nil, let target = entries[i].sets[j].targetWeightKg {
                    entries[i].sets[j].weightKg = target
                }
                if entries[i].sets[j].rpe == nil, let target = entries[i].sets[j].targetRPE {
                    entries[i].sets[j].rpe = target
                }
                if entries[i].sets[j].rir == nil, let target = entries[i].sets[j].targetRIR {
                    entries[i].sets[j].rir = target
                }
            }
        }
    }

    private func fillSuggested() {
        for i in entries.indices {
            if let suggestions = entries[i].progressionSuggestions {
                for j in entries[i].sets.indices {
                    if j < suggestions.count {
                        let s = suggestions[j]
                        if entries[i].sets[j].weightKg == nil, let w = s.weightKg {
                            entries[i].sets[j].weightKg = w
                        }
                        if entries[i].sets[j].reps == nil, let r = s.reps {
                            entries[i].sets[j].reps = r
                        }
                        if entries[i].sets[j].rpe == nil, let r = s.rpe {
                            entries[i].sets[j].rpe = r
                        }
                    }
                }
            } else {
                // Fallback to ghost targets
                for j in entries[i].sets.indices {
                    if entries[i].sets[j].reps == nil, let target = entries[i].sets[j].targetReps {
                        entries[i].sets[j].reps = target
                    }
                    if entries[i].sets[j].weightKg == nil, let target = entries[i].sets[j].targetWeightKg {
                        entries[i].sets[j].weightKg = target
                    }
                    if entries[i].sets[j].rpe == nil, let target = entries[i].sets[j].targetRPE {
                        entries[i].sets[j].rpe = target
                    }
                    if entries[i].sets[j].rir == nil, let target = entries[i].sets[j].targetRIR {
                        entries[i].sets[j].rir = target
                    }
                }
            }
        }
    }
}
