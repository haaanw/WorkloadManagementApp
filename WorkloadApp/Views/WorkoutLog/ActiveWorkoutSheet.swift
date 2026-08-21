import SwiftUI
import SwiftData

struct ActiveWorkoutSheet: View {
    var template: WorkoutTemplate?
    /// The verdict-resolved plan to launch. Mutually exclusive with `template` (see the three inits):
    /// a sheet is EITHER a template/blank session OR a resolved-prescription session OR a
    /// voice/text-parsed session — never a combination.
    var resolvedPlan: ResolvedSessionPlan?
    /// The narrated session to review before saving (voice/text logging, Phase C). Mutually exclusive
    /// with both paths above. Unlike them this describes work ALREADY DONE, so its sets arrive
    /// committed (`isDone == true`) and nothing is overlaid onto the spoken numbers.
    private let parsedSession: WorkoutVoiceLogService.ParsedSessionDraft?
    /// Session notes to persist with the saved session. Currently carried only by the voice-capture
    /// "log manually" fallback, which hands the raw transcript to a blank sheet so the athlete never
    /// loses what they said while re-entering it by hand.
    private let initialNotes: String?

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var athletes: [Athlete]
    // The athlete's own movements, needed by the live voice ingest so a spoken name resolves
    // against the same pool the picker and the parsed-session path use (catalog + customs).
    @Query private var customExercises: [CustomExercise]
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
    @State private var showWorkoutImport = false
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
    // Folded names the parser could not resolve against the catalog or the athlete's customs.
    // Filled once on the parsed-session load; drives the "NEW EXERCISE" card annotation.
    @State private var unresolvedNames: Set<String> = []

    private var athlete: Athlete? { athletes.first }

    /// Template / blank session path (unchanged). Never carries a resolved plan or a parsed session.
    /// `initialNotes` is the only addition: the voice-capture "log manually" fallback seeds the blank
    /// sheet with the transcript so the spoken text survives into the saved session.
    init(template: WorkoutTemplate? = nil, initialNotes: String? = nil) {
        self.template = template
        self.resolvedPlan = nil
        self.parsedSession = nil
        self.initialNotes = initialNotes
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
        self.parsedSession = nil
        self.initialNotes = nil
        _sportType = State(initialValue: resolvedPlan.sportType)
        _sessionType = State(initialValue: resolvedPlan.sessionType)
        _sessionStartChoice = State(
            initialValue: SessionStartMapper.choice(
                sportType: resolvedPlan.sportType,
                sessionType: resolvedPlan.sessionType
            )
        )
    }

    /// Voice/text-parsed session path: a session the athlete NARRATED after doing it. Mutually
    /// exclusive with the two paths above — both are forced nil so no two can combine. The review
    /// surface is the same sheet on purpose (one editor for every way a session reaches the log).
    init(parsedSession: WorkoutVoiceLogService.ParsedSessionDraft) {
        self.template = nil
        self.resolvedPlan = nil
        self.parsedSession = parsedSession
        self.initialNotes = nil
        _sportType = State(initialValue: parsedSession.sportType)
        _sessionType = State(initialValue: parsedSession.sessionType)
        _sessionStartChoice = State(
            initialValue: SessionStartMapper.choice(
                sportType: parsedSession.sportType,
                sessionType: parsedSession.sessionType
            )
        )
    }

    var elapsed: TimeInterval {
        Date.now.timeIntervalSince(startTime)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            InstrumentSheetHeader(title: "nav.workout") {
                SheetHeaderButton(title: "action.cancel") { dismiss() }
            } trailing: {
                SheetHeaderButton(title: "action.finish", emphasis: true) {
                    showFinishConfirmation = true
                }
            }
            ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Session info (round 6 redesign, HAN): the primary decision — what
                    // are you training — leads; the optional session name is demoted
                    // below it; and the elapsed timer is a LABELED annotation stamp, not
                    // a giant bare numeral (an unlabeled "0m" hero read as "0 kg").
                    VStack(spacing: Spacing.sm) {
                        SessionStartPicker(
                            choice: $sessionStartChoice,
                            sportType: $sportType,
                            sessionType: $sessionType,
                            matchTier: $matchTier,
                            defaultSessionType: defaultSessionType(for:)
                        )

                        if template == nil,
                           resolvedPlan == nil,
                           sessionStartChoice == .strength,
                           entries.isEmpty {
                            Button {
                                Haptics.tap()
                                showWorkoutImport = true
                            } label: {
                                Label("action.importPlan", systemImage: "square.and.arrow.down")
                                    .font(.Tokens.label)
                                    .foregroundStyle(ColorTokens.text2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, Spacing.xs)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.pressable)
                            .padding(.horizontal, Spacing.sm)
                            .background(ColorTokens.surfaceEl, in: RoundedRectangle(cornerRadius: CornerTokens.card))
                            .overlay(RoundedRectangle(cornerRadius: CornerTokens.card).stroke(ColorTokens.divider, lineWidth: 0.5))
                            .transition(.opacity)
                        }

                        TextField(String(localized: "workout.field.sessionName.placeholder", defaultValue: "Session Name (optional)"), text: $sessionName)
                            .textFieldStyle(SharpTextFieldStyle())
                            .accessibilityIdentifier("activeWorkout.sessionName")

                        // The running clock as marginalia: a machine stamp with its unit
                        // of meaning attached, aligned leading like every other stamp.
                        TimelineView(.periodic(from: startTime, by: 1)) { _ in
                            AnnotationLabel(
                                "\(LocalePinnedStrings.localized("workout.label.elapsed", locale: locale)) · \(Date.durationString(seconds: Int(elapsed), locale: locale))"
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.sm)
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
                    ForEach(Array(entries.enumerated()), id: \.element.id) { entryIndex, _ in
                        ExerciseEntryCard(
                            entry: $entries[entryIndex],
                            sportType: sportType,
                            weightUnit: athlete?.weightUnit ?? .kg,
                            isNewExercise: unresolvedNames.contains(
                                Self.foldedName(entries[entryIndex].exerciseName)
                            )
                        )
                        .entranceReveal(index: entryIndex)
                        Rectangle()
                            .fill(ColorTokens.divider)
                            .frame(height: 0.5)
                    }
                    .onDelete { indexSet in
                        Haptics.warning()
                        withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                            entries.remove(atOffsets: indexSet)
                        }
                    }

                    // Live incremental voice logging (Phase D). Inline, never a sheet: the set
                    // list above stays visible so a spoken set is SEEN landing. Present on every
                    // path — a narrated session can be extended live, the same way a template
                    // session can. The card owns the microphone; this sheet owns the appending.
                    VoiceDictationCard { text in
                        await ingestUtterance(text)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(ColorTokens.background)

                    Rectangle()
                        .fill(ColorTokens.divider)
                        .frame(height: 0.5)

                    // Add exercise button
                    Button {
                        Haptics.tap()
                        showExercisePicker = true
                    } label: {
                        Label("action.addExercise", systemImage: "plus")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                    }
                    .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                    .accessibilityIdentifier("activeWorkout.addExercise")
                    .background(ColorTokens.background)

                    // Duplicate the most-recently-added exercise as a fresh GHOST-scaffolded
                    // entry (§E.2): same name/category/muscle, set count carried, every value
                    // ghosted (isDone=false) so building a multi-exercise session is fast
                    // without re-picking — and nothing is logged until the user confirms.
                    if entries.last != nil {
                        Rectangle()
                            .fill(ColorTokens.divider)
                            .frame(height: 0.5)
                        Button {
                            Haptics.tap()
                            withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                                duplicateLastExercise()
                            }
                        } label: {
                            Label("action.duplicateExercise", systemImage: "plus.square.on.square")
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.sm)
                        }
                        .buttonStyle(.pressable(scale: 1, opacity: 0.6))
                        .background(ColorTokens.background)
                    }
                }
            }
            .background(ColorTokens.background)
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
                    withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                        entries.append(draft)
                    }
                }
            }
            .sheet(isPresented: $showWorkoutImport) {
                WorkoutImportSheet { importedTemplate in
                    loadFromTemplate(importedTemplate)
                }
                .environment(container)
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
                VStack(spacing: Spacing.xs) {
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
                .padding(.bottom, Spacing.sm)
                .padding(.horizontal, Spacing.sm)
            }
            .animation(Motion.resolved(Motion.entrance, reduceMotion: reduceMotion), value: showSpikeAlert)
            .animation(Motion.resolved(Motion.entrance, reduceMotion: reduceMotion), value: showPRCelebration)
            .overlay(alignment: .bottom) {
                if showTemplateSavedToast {
                    ToastBanner(
                        message: templateSaveError ? String(localized: "error.templateSave", defaultValue: "Couldn't save template. Try again.") : String(localized: "message.templateSaved", defaultValue: "Template saved"),
                        isError: templateSaveError,
                        isPresented: $showTemplateSavedToast
                    )
                    .padding(.bottom, Spacing.sm)
                    .padding(.horizontal, Spacing.sm)
                }
            }
            .animation(Motion.resolved(Motion.entrance, reduceMotion: reduceMotion), value: showTemplateSavedToast)
            .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: sessionStartChoice)
            .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: entries.count)
            // Zero-done save guard: Finish was tapped with NO set marked done. Saving now would
            // log an empty session, so Cancel keeps the user in the sheet and Discard exits
            // without persistence.
            .confirmationDialog(
                String(localized: "workout.save.noDone.title", defaultValue: "No sets logged"),
                isPresented: $showZeroDoneGuard,
                titleVisibility: .visible
            ) {
                Button(String(localized: "workout.save.noDone.discard", defaultValue: "Discard session"), role: .destructive) {
                    dismiss()
                }
                Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "workout.save.noDone.message", defaultValue: "Nothing will be logged. Tap Log set to record sets, or discard this session?"))
            }
            .onAppear {
                // Warm the haptic generators: this is the highest-interaction screen (per-set
                // done taps, weight/rep commits) so latency on the first tap matters.
                Haptics.prepare()
                if template != nil && entries.isEmpty {
                    loadFromTemplate()
                } else if let resolvedPlan, entries.isEmpty {
                    loadFromResolvedPlan(resolvedPlan)
                } else if let parsedSession, entries.isEmpty {
                    loadFromParsedSession(parsedSession)
                }
            }
            // Keyboard avoidance (round 4): SwiftUI's automatic scroll surfaces only the
            // bare focused field; the row's label, chips, and tape stay buried under the
            // pad. Rows call this closure on focus; centering puts the whole set row in
            // the upper half of the screen, above the keyboard.
            .environment(\.setRowScroller) { id in
                withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                    scrollProxy.scrollTo(id, anchor: .center)
                }
            }
            }
            }
            .toolbar(.hidden, for: .navigationBar)
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
        loadFromTemplate(tmpl)
    }

    private func loadFromTemplate(_ tmpl: WorkoutTemplate) {
        sessionName = tmpl.templateName
        sportType = tmpl.sportType
        sessionType = tmpl.sessionType
        sessionStartChoice = SessionStartMapper.choice(
            sportType: tmpl.sportType,
            sessionType: tmpl.sessionType
        )
        matchTier = nil
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

    // MARK: - Parsed-Session Loading (voice/text → workout)

    /// Populate drafts DIRECTLY from a narrated session. Like the resolved-plan path this bypasses
    /// every overlay the template path applies — NO `ProgressionEngine`, NO history prefill, NO
    /// template fallback: the SPOKEN numbers ARE the session, and a suggestion written over them
    /// would silently rewrite what the athlete reported. `sourceTemplate` stays nil (no FillButtonBar,
    /// no usage stats). Sets arrive committed (`isDone == true` from the mapper) because the work is
    /// already done — the sheet is a review surface here, not a live logger.
    private func loadFromParsedSession(_ draft: WorkoutVoiceLogService.ParsedSessionDraft) {
        sessionName = draft.sessionName
        sportType = draft.sportType
        sessionType = draft.sessionType
        sessionStartChoice = SessionStartMapper.choice(
            sportType: draft.sportType,
            sessionType: draft.sessionType
        )
        entries = draft.entries
        sessionRPE = Double(draft.sessionRPE ?? 5)
        unresolvedNames = Set(draft.unresolvedExerciseNames.map(Self.foldedName))

        // Honest duration: the elapsed clock starts when the sheet OPENS, so a narrated session
        // would otherwise save as the two minutes spent reviewing it — and durationSeconds feeds
        // internal load. Back-date the start so elapsed reflects the session the athlete described.
        if let minutes = draft.durationMinutes, minutes > 0 {
            startTime = Date.now.addingTimeInterval(-Double(minutes) * 60)
        }

        persistUnresolvedExercises(named: draft.unresolvedExerciseNames, from: draft.entries)
    }

    /// Persist names the parser could not resolve as the athlete's own `CustomExercise` rows, so the
    /// next session (spoken, typed, or picked) finds them locally instead of re-asking the parser.
    /// Deduped case- and diacritic-insensitively against BOTH the existing custom rows and the
    /// bundled catalog, matching `ExercisePickerView.instantlyAddSearchText`. Runs off the render
    /// pass so the review surface never waits on a SwiftData save.
    private func persistUnresolvedExercises(named names: [String], from drafts: [ExerciseEntryDraft]) {
        guard !names.isEmpty else { return }
        guard let athleteID = athlete?.id else { return }
        // Only value types cross into the Task (ids + enums), never the @Model objects — the same
        // discipline `instantlyAddSearchText` follows, so the async hop stays free of live models.
        let context = modelContext
        let sport = sportType
        let pending: [(name: String, category: ExerciseCategory, muscle: MuscleGroup)] = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { name in
                // Category/muscle come from the entry the parser built for this name, so the saved
                // row carries the same classification the athlete is about to review. `.fullBody` is
                // the never-nil floor the movement bank guarantees.
                let source = drafts.first { Self.foldedName($0.exerciseName) == Self.foldedName(name) }
                return (name, source?.exerciseCategory ?? .compound, source?.muscleGroup ?? .fullBody)
            }
        guard !pending.isEmpty else { return }

        Task { @MainActor in
            let athleteDescriptor = FetchDescriptor<Athlete>(predicate: #Predicate { $0.id == athleteID })
            guard let owner = try? context.fetch(athleteDescriptor).first else { return }

            let existing = (try? context.fetch(FetchDescriptor<CustomExercise>())) ?? []
            var known = Set(existing.map { Self.foldedName($0.name) })
            known.formUnion(ExerciseDatabase.all.map { Self.foldedName($0.name) })

            var inserted = false
            for item in pending where known.insert(Self.foldedName(item.name)).inserted {
                let exercise = CustomExercise(
                    name: item.name,
                    exerciseCategory: item.category,
                    muscleGroup: item.muscle,
                    sportType: sport
                )
                exercise.athlete = owner
                context.insert(exercise)
                inserted = true
            }
            guard inserted else { return }
            do {
                try context.save()
            } catch {
                print("Failed to persist parsed custom exercises: \(error)")
            }
        }
    }

    /// Case + diacritic folding matching `ExerciseCatalogStore`'s normalization, so name matching
    /// here agrees with the picker and the catalog index.
    private static func foldedName(_ name: String) -> String {
        name.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    // MARK: - Live Voice Ingest (Phase D)

    /// Turn ONE utterance ("eighty for five", "same weight, five more", "bench press 80 kilos
    /// times 5") into an appended set. Two tiers, deliberately in this order:
    ///
    /// 1. `VoiceSetUtteranceParser` — on-device, offline, instant, and free. It answers the shapes
    ///    an athlete actually speaks between sets, which is the overwhelming majority of traffic.
    /// 2. The LLM log parser — only when the local grammar is not confident. It costs a round trip
    ///    and a quota unit, so it is the exception, not the path.
    ///
    /// Anything neither tier can apply comes back as `.needsFallbackChip`: the card keeps the
    /// athlete's words in an editable field. An utterance is never silently dropped.
    @MainActor
    private func ingestUtterance(_ text: String) async -> UtteranceOutcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .needsFallbackChip }

        let outcome: UtteranceOutcome
        if let parsed = VoiceSetUtteranceParser.parse(trimmed, weightUnit: athlete?.weightUnit ?? .kg) {
            outcome = applyParsedUtterance(parsed)
        } else {
            outcome = await ingestViaLLM(trimmed)
        }

        // The same commit haptic the per-set Log action fires — logging a set by voice must feel
        // identical to logging it by hand.
        if case .added = outcome { Haptics.success() }
        return outcome
    }

    /// Where a spoken set belongs.
    private enum UtteranceTarget {
        /// An exercise already in this session.
        case existing(Int)
        /// A movement not in the session yet. `isUnresolved` marks a name that matched neither the
        /// catalog nor the athlete's customs, so it is persisted as a custom exercise and stamped
        /// "NEW EXERCISE" on its card — the same treatment the parsed-session path gives.
        case new(name: String, category: ExerciseCategory, muscle: MuscleGroup?, isUnresolved: Bool)
        /// Nothing to attach the set to (no name spoken and no entries at all).
        case unattached
    }

    /// Apply a locally parsed utterance. Every branch that cannot honestly produce a logged set
    /// returns `.needsFallbackChip` rather than inventing one — a fabricated set poisons PRs,
    /// volume, and the load pipeline far worse than one round of manual repair.
    private func applyParsedUtterance(_ result: VoiceSetUtteranceParser.Result) -> UtteranceOutcome {
        if result.repeatLast {
            return repeatLastDoneSet()
        }

        switch resolveTarget(spokenName: result.exerciseName) {
        case .existing(let index):
            var newSet = SetDraft()
            newSet.reps = result.reps
            // "same weight" resolves against the TARGET entry's own history in this session —
            // the last set of this movement that actually carried a weight.
            newSet.weightKg = result.sameWeight ? lastWeightKg(in: entries[index]) : result.weightKg
            newSet.durationSeconds = result.durationSeconds
            newSet.rpe = result.rpe
            // An RPE alone is not a set. Without at least one measurement there is nothing to log,
            // so the words go back to the athlete instead of becoming an empty done row.
            guard newSet.reps != nil || newSet.weightKg != nil || newSet.durationSeconds != nil else {
                return .needsFallbackChip
            }
            newSet.isDone = true
            withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                entries[index].sets.append(newSet)
            }
            return .added(exerciseName: entries[index].exerciseName)

        case .new(let name, let category, let muscle, let isUnresolved):
            var draft = ExerciseEntryDraft(
                exerciseName: name,
                exerciseCategory: category,
                muscleGroup: muscle
            )
            var newSet = SetDraft()
            newSet.reps = result.reps
            // No `sameWeight` antecedent exists for a movement that isn't in the session yet.
            newSet.weightKg = result.weightKg
            newSet.durationSeconds = result.durationSeconds
            newSet.rpe = result.rpe
            // Naming a movement with no numbers ("next up, incline bench") is a legitimate way to
            // open an exercise — it just opens an UNDONE shell, never a fabricated logged set.
            newSet.isDone = newSet.reps != nil || newSet.weightKg != nil || newSet.durationSeconds != nil
            draft.sets = [newSet]

            if isUnresolved {
                unresolvedNames.insert(Self.foldedName(name))
                persistUnresolvedExercises(named: [name], from: [draft])
            }
            withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                entries.append(draft)
            }
            return .added(exerciseName: name)

        case .unattached:
            return .needsFallbackChip
        }
    }

    /// Resolve which entry a spoken utterance belongs to.
    ///
    /// A spoken name is matched against THIS SESSION's entries first — mid-workout, "bench" almost
    /// always means the bench entry already on screen, and matching the catalog first would open a
    /// duplicate card. Only an unmatched name goes to `resolveLocalExercise` (catalog + customs),
    /// whose canonical name keeps history and PRs continuous across a spoken variant.
    ///
    /// With no name spoken, the set joins the exercise that owns the most recent LOGGED set — the
    /// one being worked on — falling back to the last entry when nothing is logged yet.
    private func resolveTarget(spokenName: String?) -> UtteranceTarget {
        let spoken = spokenName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !spoken.isEmpty else {
            if let location = lastDoneSetLocation() { return .existing(location.entry) }
            if !entries.isEmpty { return .existing(entries.count - 1) }
            return .unattached
        }

        if let index = entryIndex(matching: spoken) { return .existing(index) }

        if let resolved = WorkoutLLMImportService.resolveLocalExercise(
            name: spoken,
            sportType: sportType,
            catalogExercises: ExerciseDatabase.all,
            customExercises: customExercises
        ) {
            let canonical = resolved.matchedCatalogName ?? resolved.name
            // The canonical name can match an entry the spoken variant missed ("incline press" →
            // "Incline Bench Press"), so check once more before opening a second card for it.
            if let index = entryIndex(matching: canonical) { return .existing(index) }
            return .new(
                name: canonical,
                category: resolved.exerciseCategory,
                muscle: resolved.muscleGroup,
                isUnresolved: false
            )
        }

        let classification = ExerciseClassifier.classify(spoken)
        return .new(
            name: spoken,
            category: classification.category,
            muscle: classification.muscleGroup,
            isUnresolved: true
        )
    }

    /// Clone the most recent LOGGED set in the session as another logged set on the same entry —
    /// the spoken form of the card's own "Repeat last set" action, and identical in effect.
    /// A brand-new `SetDraft` is built field by field on purpose: `SetDraft.id` is a stored
    /// default, so copying the struct would put two rows with the same identity in one `ForEach`.
    private func repeatLastDoneSet() -> UtteranceOutcome {
        guard let location = lastDoneSetLocation() else { return .needsFallbackChip }
        let source = entries[location.entry].sets[location.set]

        var clone = SetDraft()
        clone.reps = source.reps
        clone.weightKg = source.weightKg
        clone.durationSeconds = source.durationSeconds
        clone.distanceMeters = source.distanceMeters
        clone.rpe = source.rpe
        clone.rir = source.rir
        clone.isWarmup = source.isWarmup
        clone.isDone = true

        withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
            entries[location.entry].sets.append(clone)
        }
        return .added(exerciseName: entries[location.entry].exerciseName)
    }

    /// The most recent logged set, searched from the end of the session backwards.
    private func lastDoneSetLocation() -> (entry: Int, set: Int)? {
        for entryIndex in entries.indices.reversed() {
            if let setIndex = entries[entryIndex].sets.lastIndex(where: { $0.isDone }) {
                return (entryIndex, setIndex)
            }
        }
        return nil
    }

    /// The last weight this entry actually carried in this session — the antecedent of "same weight".
    private func lastWeightKg(in entry: ExerciseEntryDraft) -> Double? {
        entry.sets.last { $0.weightKg != nil }?.weightKg
    }

    /// Match a spoken/parsed name against the session's entries. Exact normalized equality wins;
    /// otherwise the LAST containment match wins, because a session holding both "Bench Press" and
    /// "Close-Grip Bench Press" means "bench" refers to whichever was added most recently.
    ///
    /// `WorkoutLLMImportService`'s own fuzzy scorer is file-private, so this is deliberately the
    /// narrower rule — containment, not scoring — rather than a second copy of that algorithm.
    private func entryIndex(matching name: String) -> Int? {
        let key = Self.matchKey(name)
        guard !key.isEmpty else { return nil }
        if let exact = entries.firstIndex(where: { Self.matchKey($0.exerciseName) == key }) {
            return exact
        }
        return entries.lastIndex { entry in
            let entryKey = Self.matchKey(entry.exerciseName)
            guard !entryKey.isEmpty else { return false }
            return entryKey.contains(key) || key.contains(entryKey)
        }
    }

    /// Case/diacritic-folded, punctuation-stripped, single-spaced — the same normalization shape
    /// `WorkoutLLMImportService` uses internally, so "Close-Grip Bench" and "close grip bench" are
    /// one key.
    private static func matchKey(_ name: String) -> String {
        foldedName(name)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// Second tier: hand the utterance to the LLM log parser and merge whatever it returns.
    /// One utterance parses small, so every entry it produces is merged — sets onto a
    /// folded-name match, otherwise the whole entry is appended. Sets keep the mapper's
    /// `isDone == true`: the athlete is reporting work already performed.
    @MainActor
    private func ingestViaLLM(_ text: String) async -> UtteranceOutcome {
        do {
            let response = try await WorkoutVoiceLogService.parseLoggedWorkoutText(
                text,
                client: container.supabase
            )
            let draft = WorkoutVoiceLogService.mapToParsedSessionDraft(
                response,
                transcript: text,
                catalogExercises: ExerciseDatabase.all,
                customExercises: customExercises
            )
            return mergeParsedEntries(draft)
        } catch {
            // Offline, quota, or an unreadable response — all the same to the card: give the
            // athlete their words back rather than an error they cannot act on.
            print("Voice ingest fallback failed: \(error)")
            return .needsFallbackChip
        }
    }

    private func mergeParsedEntries(_ draft: WorkoutVoiceLogService.ParsedSessionDraft) -> UtteranceOutcome {
        guard !draft.entries.isEmpty else { return .needsFallbackChip }

        var firstTouched: String?
        withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
            for parsed in draft.entries {
                if let index = entryIndex(matching: parsed.exerciseName) {
                    entries[index].sets.append(contentsOf: parsed.sets)
                    if firstTouched == nil { firstTouched = entries[index].exerciseName }
                } else {
                    entries.append(parsed)
                    if firstTouched == nil { firstTouched = parsed.exerciseName }
                }
            }
        }

        guard let firstTouched else { return .needsFallbackChip }
        unresolvedNames.formUnion(draft.unresolvedExerciseNames.map(Self.foldedName))
        persistUnresolvedExercises(named: draft.unresolvedExerciseNames, from: draft.entries)
        return .added(exerciseName: firstTouched)
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
        // Carried only by the voice-capture "log manually" fallback (nil on every other path), so
        // the transcript the athlete re-entered by hand is kept beside the session it describes.
        if let initialNotes, !initialNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            session.notes = initialNotes
        }
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
                // is the dominant signal → warning; a PR with no spike → success.
                //
                // Round 8 (HAN): Finish RETURNS, always. The in-sheet banner hold —
                // "sheet stays open until the last banner is tapped away" — read as the
                // save not working. PRs remain recorded and visible in history/PR
                // surfaces; the spike still speaks through the warning haptic.
                if showSpikeAlert {
                    Haptics.warning()
                } else if showPRCelebration {
                    Haptics.success()
                }
                showSpikeAlert = false
                showPRCelebration = false
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
    ///
    /// Round 8 (HAN): `dismiss()` fired while the Finish child sheet was still tearing
    /// down, and SwiftUI drops a parent dismissal issued mid-child-transition — so the
    /// athlete landed back on the logging page. Close the child explicitly, then
    /// dismiss the sheet after the transition beat.
    private func finishAfterSave() {
        showFinishConfirmation = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            dismiss()
        }
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
    /// The parser could not match this movement to the catalog or the athlete's customs, so the
    /// card says so — quietly, in the annotation voice. Only the parsed-session path sets it.
    var isNewExercise: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

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
        withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
            entry.sets.append(draft)
        }
        Haptics.tap()
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
        withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
            entry.sets.append(clone)
        }
        Haptics.success()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(entry.exerciseName)
                    .font(.Tokens.sectionHead)
                    .foregroundStyle(ColorTokens.text1)
                Spacer()
                if isNewExercise {
                    // A provenance stamp beside the movement name — marginalia (v6). The uppercase
                    // transform belongs to `AnnotationLabel`, so the catalog value stays sentence case.
                    AnnotationLabel(
                        LocalePinnedStrings.localized(
                            "voice.review.newExercise",
                            defaultValue: "New exercise",
                            locale: locale
                        )
                    )
                }
                if let muscle = entry.muscleGroup {
                    // A taxonomy tag beside the movement name — marginalia (v6).
                    AnnotationLabel(muscle.displayName, color: ColorTokens.text2)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)

            // Suggestion rationale
            if let rationale = entry.suggestionRationale {
                Text(rationale)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.bottom, Spacing.xs)
            } else if entry.sets.first?.isFromHistory == true {
                // A provenance stamp ("prefilled from last") — marginalia (v6).
                AnnotationLabel(key: "exercise.label.prefilledFromLast")
                    .padding(.horizontal, Spacing.sm)
                    .padding(.bottom, Spacing.xs)
            }

            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)

            // Column headers based on input mode. RPE is no longer a fixed column — it lives
            // behind a per-row "+ RPE" chip (fast path = weight + reps only).
            switch inputMode {
            case .weightReps:
                // No header row: the field-first row (variant C) labels its own wells
                // (WEIGHT · KG / REPS), and a second set of column captions above them
                // read as duplication aligned to a layout that no longer exists.
                EmptyView()
            case .repsOnly:
                setHeaderRow(columns: [
                    ("table.header.set", 32),
                    ("table.header.reps", 0)
                ])
            case .distanceDuration:
                setHeaderRow(columns: [
                    ("table.header.set", 32),
                    ("table.header.dist", 0),
                    ("table.header.time", 0)
                ])
            case .durationOnly:
                setHeaderRow(columns: [
                    ("table.header.set", 32),
                    ("table.header.timeMin", 0)
                ])
            }

            ForEach($entry.sets) { $set in
                let setIndex = entry.sets.firstIndex(where: { $0.id == set.id }) ?? 0
                VStack(spacing: 0) {
                    // The scroll target for keyboard avoidance — the ROW, not the field,
                    // so the label/chips/tape scroll clear of the pad together.
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
                .id(set.id)
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
                    .overlay(RoundedRectangle(cornerRadius: CornerTokens.control).stroke(ColorTokens.divider, lineWidth: 0.5))
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
                    RoundedRectangle(cornerRadius: CornerTokens.control)
                        .stroke(ColorTokens.divider, style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                )
            }
            .buttonStyle(.pressable(scale: 1, opacity: 0.6))
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
        }
        .background(ColorTokens.surfaceEl)
    }

    /// Column headers for the set table — axis labels for a column of readings, so the ANNOTATION
    /// voice at the axis size (v6).
    ///
    /// The tuple carries a `LocalizedStringKey` again (Wave 3). Wave 2 changed it to a resolved
    /// `String` only because `AnnotationLabel` had no key initializer, which pushed all four call
    /// sites onto `String(localized:)` — and that reads the PROCESS locale, while the app pins its
    /// language with `.environment(\.locale, localeManager.activeLocale)` in `AppRouter`. These
    /// four headers had therefore stopped following an in-app language switch. `AnnotationLabel`
    /// gained `init(key:)` during Wave 2 verification precisely to undo this class of regression;
    /// this helper is one of the sites that was still holding the flattened form.
    private func setHeaderRow(columns: [(LocalizedStringKey, CGFloat)]) -> some View {
        HStack {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, col in
                if col.1 > 0 {
                    AnnotationLabel(key: col.0, size: .small).frame(width: col.1)
                } else {
                    AnnotationLabel(key: col.0, size: .small).frame(maxWidth: .infinity)
                }
            }
        }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Per-set RPE is collapsed behind a "+ RPE" chip; start expanded only if RPE already set.
    @State private var showRPE = false

    /// Shared inline-keypad focus for this row's weight + reps fields, so a weight keypad
    /// commit advances to reps without dismissing/re-summoning the keyboard (§5.5).
    @FocusState private var focusField: SetFocusField?

    /// Sheet-injected scroll closure — centers this row above the keyboard on focus.
    @Environment(\.setRowScroller) private var scrollToRow

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

    /// Direction mark for the progression suggestion, drawn from v6's sanctioned annotation glyph
    /// set (`▲ △ ▼ ▽` deltas, `=` for hold) rather than an SF Symbol. The row it labels is
    /// marginalia, so it renders in Fragment Mono — and an SF Symbol inside a mono annotation
    /// would put two faces on one 12pt line for no gain. SF Symbols remain correct everywhere
    /// they are actual UI glyphs (`chevron.right`, the done checkmark); this one was a delta.
    private var suggestionGlyph: String {
        switch progressionType {
        case .increase: return "▲"
        default: return "="
        }
    }

    /// Collapsed "+ RPE" chip → inline RPE stepper. Fast path never requires RPE.
    /// Parliament spec (2026-08-13): for .weightReps this renders ONLY when the set
    /// carries a plan-authored target, so the stepper shows directly (the "+ RPE" chip
    /// path is dead there); other modes keep the chip.
    @ViewBuilder private var rpeControl: some View {
        if showRPE || set.rpe != nil || (inputMode == .weightReps && set.targetRPE != nil) {
            SetStepperDouble(
                value: $set.rpe,
                increment: 1,
                placeholder: String(localized: "metric.rpe", defaultValue: "RPE"),
                ghostBaseline: set.targetRPE,
                floor: 0,
                fractionDigits: 0
            )
            .frame(width: 120)
            .transition(.opacity)
        } else {
            Button {
                Haptics.tap()
                withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                    showRPE = true
                }
            } label: {
                Text("set.rpe.add")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xs)
                    .contentShape(Rectangle())
                    .overlay(Capsule().stroke(ColorTokens.divider, lineWidth: 0.5))
            }
            .buttonStyle(.pressable)
            .transition(.opacity)
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
            placeholder: String(localized: "metric.rir", defaultValue: "RIR"),
            ghostBaseline: set.targetRIR,
            floor: 0
        )
        .frame(width: 120)
    }

    /// Per-set DONE toggle (proposal §13, Option A). A square `Rectangle` checkbox: empty when
    /// not done, filled `text1` with a checkmark glyph when done. The square is a deliberate
    /// checkbox GLYPH (state mark, not a container plate — v3 Corner Law exempts glyphs), 0.5pt
    /// hairline `divider` border, NO accent. ≥44pt touch target at the trailing end of the row. Tapping
    /// toggles `set.isDone`, controlling whether this set is persisted by saveSession().
    @ViewBuilder private var doneToggle: some View {
        Button {
            let willComplete = !set.isDone
            withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                set.isDone.toggle()
            }
            if willComplete {
                Haptics.success()
            } else {
                Haptics.tap()
            }
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
            .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: set.isDone)
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
    /// color-alone: the word "Warmup" plus a checkbox-style square glyph communicate state. The
    /// container wears `CornerTokens.control` (v3 Corner Law; the inner square stays a checkbox
    /// glyph), 0.5pt hairline `divider`, NO accent. Warmups are still excluded from the
    /// suggestion source + PR by the existing logic; this only makes the flag visible/legible.
    @ViewBuilder private var warmupToggle: some View {
        Button {
            set.isWarmup.toggle()
            Haptics.select()
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
            .overlay(RoundedRectangle(cornerRadius: CornerTokens.control).stroke(ColorTokens.divider, lineWidth: 0.5))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(String(localized: "set.warmup.label", defaultValue: "Warmup"))
        .accessibilityValue(set.isWarmup
            ? String(localized: "set.warmup.on", defaultValue: "On")
            : String(localized: "set.warmup.off", defaultValue: "Off"))
        .accessibilityAddTraits(set.isWarmup ? [.isButton, .isSelected] : .isButton)
    }

    /// Compact one-line summary of a completed set (§5.3). Tapping re-expands the full
    /// editable row (the set stays isDone). `text2`, monospacedDigit, hairline separators, no accent.
    @ViewBuilder private var collapsedSummary: some View {
        Button {
            Haptics.tap()
            withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                expandOverride = true
            }
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
                    // A flag on the reading, not speech — annotation (v6). The set index and the
                    // summary itself stay in the working voice: they are the row's DATA, and the
                    // annotation layer is marginalia around data, never the data.
                    AnnotationLabel(key: "set.warmup.label")
                }
                Spacer()
                Image(systemName: "checkmark")
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text3)
            }
            .padding(.horizontal, Spacing.sm)
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
            if set.weightKg == 0, category == .bodyweight {
                // 0 kg on a bodyweight movement reads BW, never "0kg × 8".
                return String(format: String(localized: "set.summary.bwReps", defaultValue: "BW × %d"), reps)
            }
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

    /// The .weightReps row controls — field-first (HAN-gated variant C, 2026-08-12):
    /// the labeled weight/reps wells + chips + reps tape as one block, with RPE and the
    /// done toggle on their own line beneath. The block stacks internally, so the old
    /// ViewThatFits horizontal/vertical fallback is no longer needed.
    @ViewBuilder private var weightRepsControls: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SetEntryFields(
                weightKg: $set.weightKg,
                reps: $set.reps,
                unit: weightUnit,
                suggestedWeightKg: suggestedCenterKg,
                suggestedReps: suggestedReps,
                isBodyweight: category == .bodyweight,
                focus: $focusField,
                rowId: set.id
            )
            // Parliament spec (2026-08-13): the per-set "+ RPE" chip is gone — session RPE
            // at Finish is the only free-standing effort input. The effort stepper appears
            // ONLY when the set carries a PLAN-AUTHORED target (RIR or RPE): a prescribed
            // target is plan-aware core surface, not the noise HAN flagged.
            if set.targetRIR != nil || set.targetRPE != nil {
                effortControl
            }
            logControl
        }
    }

    /// The explicit per-set log gate (parliament spec, 2026-08-13). Replaces the ✓ box
    /// whose meaning HAN could not read. Materialize ≠ log: typing, chips, and scrubs
    /// write VALUES; only this action records the set as performed. Logging fills any
    /// remaining ghost (suggested reps, else 8; suggested weight when one exists),
    /// dismisses the keyboard, fires the success haptic, and the row collapses to its
    /// one-line summary at once — the visible state change the ✓ never gave.
    @ViewBuilder private var logControl: some View {
        if set.isDone {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "checkmark")
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text1)
                Text("set.action.logged")
                    .font(.Tokens.smallLabel)
                    .foregroundStyle(ColorTokens.text1)
                Spacer(minLength: 0)
                // Recoverability: an accidental log must be reversible in place.
                Button {
                    Haptics.tap()
                    withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                        set.isDone = false
                    }
                } label: {
                    Text("set.action.unlog")
                        .font(.Tokens.smallLabel)
                        .foregroundStyle(ColorTokens.text2)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.baselinePair)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
            }
            .padding(.vertical, Spacing.baselinePair)
        } else {
            Button(action: logSet) {
                Text("set.action.log")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xs)
                    .contentShape(Rectangle())
                    .overlay(RoundedRectangle(cornerRadius: CornerTokens.control).stroke(ColorTokens.dividerStrong, lineWidth: 0.5))
            }
            .buttonStyle(.pressable(scale: 1, opacity: 0.6))
            .accessibilityHint(String(localized: "set.action.log.hint", defaultValue: "Records this set as performed"))
        }
    }

    private func logSet() {
        // Accepting a ghost IS the one-tap "same as last" loop: fill what the athlete
        // never edited from the suggestion (reps fall back to the universal 8).
        if set.reps == nil {
            set.reps = suggestedReps ?? 8
        }
        if set.weightKg == nil {
            if let suggested = suggestedCenterKg {
                set.weightKg = suggested
            } else if category == .bodyweight {
                // Council ruling (2026-08-13): 0 kg MEANS bodyweight — logging a
                // pull-up with no added load records an explicit BW set, not a blank.
                set.weightKg = 0
            }
        }
        focusField = nil
        withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
            set.isDone = true
            expandOverride = nil
        }
        Haptics.success()
    }

    var body: some View {
        Group {
            if isCollapsed {
                collapsedSummary
                    .transition(.opacity)
            } else {
                expandedRow
                    .transition(.opacity)
            }
        }
        .animation(Motion.resolved(Motion.state, reduceMotion: reduceMotion), value: isCollapsed)
        // Keyboard avoidance (round 4): when one of this row's fields takes focus, ask
        // the sheet to center the row above the pad. The 0.3 s beat lets the keyboard
        // frame settle first — scrolling against a moving keyboard lands short, which
        // is exactly the "does not scroll enough" HAN reported.
        .onChange(of: focusField) { _, newValue in
            guard newValue != nil else { return }
            // Keyboard already up (row-to-row focus hop): no didShow will fire, scroll
            // after a short beat.
            let id = set.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                scrollToRow?(id)
            }
        }
        // First summon: scroll only once the keyboard's frame has settled — scrolling
        // against a moving keyboard lands short (parliament: frame-driven beats a bare
        // fixed delay).
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
            guard focusField != nil else { return }
            scrollToRow?(set.id)
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
                                placeholder: String(localized: "unit.reps.short", defaultValue: "reps"),
                                ghostBaseline: set.targetReps
                            )

                        case .distanceDuration:
                            ghostedField(
                                value: $set.distanceMeters,
                                ghost: set.targetDistanceMeters,
                                placeholder: String(localized: "unit.meter.short", defaultValue: "m"),
                                decimal: true
                            )
                            ghostedField(
                                value: $set.durationSeconds,
                                ghost: set.targetDurationSeconds,
                                placeholder: String(localized: "unit.second.short", defaultValue: "sec")
                            )

                        case .durationOnly:
                            ghostedField(
                                value: $set.durationSeconds,
                                ghost: set.targetDurationSeconds,
                                placeholder: String(localized: "unit.minute.short", defaultValue: "min")
                            )

                        case .weightReps:
                            EmptyView()
                        }

                        effortControl

                        doneToggle
                    }
                }
            }
            .font(.Tokens.label)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            // Auto-mark performed when the user actually commits a measurement value. Prefill /
            // ghost / carry writes happen before this row renders (in onAppear loaders /
            // addCarriedSet), so their initial values do NOT trigger these onChange handlers —
            // only subsequent in-row user edits do. nil → some transition = a real entry.
            .onChange(of: set.weightKg) { oldValue, newValue in
                // Parliament spec (2026-08-13): in .weightReps, materialize ≠ log — only
                // the explicit Log action records performance. Other modes keep the
                // nil→some auto-mark their steppers were built around.
                guard inputMode != .weightReps else { return }
                if oldValue == nil, newValue != nil { markSetDone() }
            }
            .onChange(of: set.reps) { oldValue, newValue in
                guard inputMode != .weightReps else { return }
                if oldValue == nil, newValue != nil { markSetDone() }
            }
            .onChange(of: set.durationSeconds) { oldValue, newValue in
                if oldValue == nil, newValue != nil { markSetDone() }
            }
            .onChange(of: set.distanceMeters) { oldValue, newValue in
                if oldValue == nil, newValue != nil { markSetDone() }
            }

            // Warmup toggle — visible, labeled, state-bearing (not color-alone). Aligned past
            // the set-number column so it reads as a per-set attribute.
            HStack(spacing: Spacing.xs) {
                warmupToggle
                Spacer()
            }
            .padding(.leading, Spacing.sm + Spacing.lg + Spacing.xs)
            .padding(.trailing, Spacing.sm)
            .padding(.bottom, Spacing.xs)

            // Progression suggestion (Pro). SPLIT VOICES, deliberately: the direction mark is a
            // delta from v6's sanctioned glyph set, so it is annotation; the suggestion itself is
            // an imperative the app SPEAKS ("maintain 80kg" / "保持 80kg"), so it is working
            // voice. Wave 2 put the whole line through `AnnotationLabel`, which rendered a
            // localized sentence as uppercase mono — DESIGN.md rule 9, "annotation is marginalia
            // … never a sentence". The a11y label keeps the spoken form.
            if let text = suggestionText {
                HStack(spacing: Spacing.xs) {
                    AnnotationLabel(suggestionGlyph)
                        .accessibilityHidden(true)
                    Text(text)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text3)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xs)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(format: String(localized: "set.suggestion.accessibility", defaultValue: "Suggested: %@"), text))
            }
        }
    }

    private func markSetDone() {
        guard !set.isDone else { return }
        withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
            set.isDone = true
        }
        Haptics.success()
    }
}

// MARK: - Fill Button Bar

struct FillButtonBar: View {
    @Binding var entries: [ExerciseEntryDraft]
    let isPro: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                Haptics.tap()
                withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                    fillLast()
                }
            } label: {
                Text("workout.fill.last")
                    .font(.Tokens.bodyMedium)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .overlay(Capsule().stroke(ColorTokens.divider, lineWidth: 0.5))
            }
            .buttonStyle(.pressable)

            if isPro {
                Button {
                    Haptics.tap()
                    withAnimation(Motion.resolved(Motion.state, reduceMotion: reduceMotion)) {
                        fillSuggested()
                    }
                } label: {
                    Text("workout.fill.suggested")
                        .font(.Tokens.bodyMedium)
                        .foregroundStyle(ColorTokens.text1)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .overlay(Capsule().stroke(ColorTokens.divider, lineWidth: 0.5))
                }
                .buttonStyle(.pressable)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
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
