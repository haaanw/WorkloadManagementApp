import SwiftUI
import SwiftData

struct ActiveWorkoutSheet: View {
    var prescription: PrescribedWorkout?

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var athletes: [Athlete]
    @State private var sessionName = ""
    @State private var sportType: SportType = .lifting
    @State private var sessionType: SessionType = .strength
    @State private var entries: [ExerciseEntryDraft] = []
    @State private var sessionRPE: Double = 5
    @State private var startTime = Date.now
    @State private var showExercisePicker = false
    @State private var showFinishConfirmation = false
    @State private var newPRs: [PersonalRecord] = []
    @State private var showPRCelebration = false
    @State private var spikeAlert: WorkloadCalculator.SpikeAlert?
    @State private var showSpikeAlert = false

    private var athlete: Athlete? { athletes.first }

    init(prescription: PrescribedWorkout? = nil) {
        self.prescription = prescription
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
                        TextField("Session Name (optional)", text: $sessionName)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .textFieldStyle(.roundedBorder)

                        Picker("Sport Type", selection: $sportType) {
                            ForEach(SportType.allCases) { sport in
                                Text(sport.displayName).tag(sport)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: sportType) { _, newSport in
                            sessionType = defaultSessionType(for: newSport)
                        }

                        Picker("Session Type", selection: $sessionType) {
                            ForEach(SessionType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        TimelineView(.periodic(from: startTime, by: 1)) { _ in
                            Text(Date.durationString(seconds: Int(elapsed)))
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

                    // Exercise entries
                    ForEach($entries) { $entry in
                        ExerciseEntryCard(entry: $entry, sportType: sportType)
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
                        Label("Add Exercise", systemImage: "plus")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .background(ColorTokens.background)
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { showFinishConfirmation = true }
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
            .alert("Finish Workout", isPresented: $showFinishConfirmation) {
                Button("Save") { saveSession() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Rate your session RPE (1-10): \(Int(sessionRPE))")
            }
            .overlay {
                if showPRCelebration {
                    PRCelebrationOverlay(prs: newPRs) {
                        showPRCelebration = false
                        if showSpikeAlert { return }
                        dismiss()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showSpikeAlert, !showPRCelebration, let spikeAlert {
                    SpikeAlertBanner(alert: spikeAlert) {
                        showSpikeAlert = false
                        dismiss()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
                    .padding(.horizontal, 16)
                }
            }
            .animation(.easeOut(duration: 0.25), value: showSpikeAlert)
            .onAppear { loadPrescription() }
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

        draft.sets = suggestion.suggestedSets.map { s in
            SetDraft(
                reps: s.reps,
                weightKg: s.weightKg,
                durationSeconds: s.durationSeconds,
                distanceMeters: s.distanceMeters,
                rpe: s.rpe,
                isFromHistory: true
            )
        }
        draft.suggestionRationale = suggestion.rationale
        draft.progressionType = suggestion.progressionType
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
        draft.sets = last.sets.map { set in
            SetDraft(
                reps: set.reps,
                weightKg: set.weightKg,
                durationSeconds: set.durationSeconds,
                distanceMeters: set.distanceMeters,
                rpe: set.rpe,
                isFromHistory: true
            )
        }
    }

    private func defaultSessionType(for sport: SportType) -> SessionType {
        switch sport {
        case .lifting, .crossfit: return .strength
        case .running, .cycling, .swimming: return .cardio
        case .teamSport: return .skill
        case .custom: return sessionType
        }
    }

    // MARK: - Prescription Loading

    private func loadPrescription() {
        guard let rx = prescription else { return }
        sessionName = rx.templateName
        sportType = rx.sportType
        sessionType = rx.sessionType

        entries = rx.sortedGroups.flatMap { group in
            group.sortedExercises.map { exercise in
                var draft = ExerciseEntryDraft(
                    exerciseName: exercise.exerciseName,
                    exerciseCategory: exercise.exerciseCategory,
                    muscleGroup: exercise.muscleGroup
                )
                draft.groupName = group.groupName
                draft.sets = exercise.sortedSets.map { set in
                    SetDraft(
                        reps: set.targetReps,
                        weightKg: set.targetWeightKg,
                        rpe: set.targetRPE,
                        rir: set.targetRIR,
                        isWarmup: set.isWarmup,
                        targetReps: set.targetReps,
                        targetWeightKg: set.targetWeightKg,
                        targetRPE: set.targetRPE
                    )
                }
                if draft.sets.isEmpty { draft.sets = [SetDraft()] }
                return draft
            }
        }
    }

    // MARK: - Save

    private func saveSession() {
        let session = WorkoutSession(
            sessionDate: startTime,
            sessionName: sessionName.isEmpty ? nil : sessionName,
            sportType: sportType,
            durationSeconds: Int(elapsed),
            sessionRPE: sessionRPE,
            sessionType: sessionType
        )

        for (index, draft) in entries.enumerated() {
            let entry = ExerciseEntry(
                exerciseName: draft.exerciseName,
                exerciseCategory: draft.exerciseCategory,
                muscleGroup: draft.muscleGroup,
                orderIndex: index
            )

            for (setIdx, setDraft) in draft.sets.enumerated() {
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
        session.athlete = athlete
        modelContext.insert(session)

        // Mark prescription completed if this was a prescribed workout
        if let rx = prescription {
            rx.markCompleted(sessionId: session.id)
            Task {
                await container.syncService.pushPrescribedWorkout(rx)
            }
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save session: \(error)")
            dismiss()
            return
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
                    return
                }

                if showSpikeAlert { return }
            } catch {
                print("Workout pipeline error: \(error)")
            }
        }

        dismiss()
    }
}

// MARK: - PR Celebration Overlay

struct PRCelebrationOverlay: View {
    let prs: [PersonalRecord]
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            ColorTokens.background.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("New PR\(prs.count > 1 ? "s" : "")!")
                    .font(.Tokens.pageTitle)
                    .foregroundStyle(ColorTokens.text1)

                VStack(spacing: 0) {
                    ForEach(prs, id: \.id) { pr in
                        HStack {
                            Text(pr.exerciseName)
                                .font(.Tokens.body)
                                .foregroundStyle(ColorTokens.text1)
                            Spacer()
                            Text("\(pr.recordType.displayName): \(String(format: "%.1f", pr.value))")
                                .font(.Tokens.label)
                                .monospacedDigit()
                                .foregroundStyle(ColorTokens.text2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        Rectangle()
                            .fill(ColorTokens.divider)
                            .frame(height: 0.5)
                    }
                }
                .background(ColorTokens.surface)
                .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))

                Button("Done") { onDismiss() }
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .overlay(Rectangle().stroke(ColorTokens.divider, lineWidth: 0.5))
            }
            .padding(32)
        }
    }
}

// MARK: - Draft Models (local state, not persisted)

struct ExerciseEntryDraft: Identifiable {
    let id = UUID()
    var exerciseName: String
    var exerciseCategory: ExerciseCategory
    var muscleGroup: MuscleGroup?
    var groupName: String?
    var sets: [SetDraft] = [SetDraft()]
    var suggestionRationale: String?
    var progressionType: ProgressionEngine.ProgressionType?
}

struct SetDraft: Identifiable {
    let id = UUID()
    var reps: Int? = nil
    var weightKg: Double? = nil
    var durationSeconds: Int? = nil
    var distanceMeters: Double? = nil
    var rpe: Double? = nil
    var rir: Int? = nil
    var isWarmup: Bool = false
    // Prescription targets (for ghost text display)
    var targetReps: Int? = nil
    var targetWeightKg: Double? = nil
    var targetRPE: Double? = nil
    // Exercise memory flag
    var isFromHistory: Bool = false
}

// MARK: - Exercise Entry Card

struct ExerciseEntryCard: View {
    @Binding var entry: ExerciseEntryDraft
    var sportType: SportType = .lifting

    private var inputMode: ExerciseInputMode {
        entry.exerciseCategory.inputMode
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Suggestion rationale
            if let rationale = entry.suggestionRationale {
                Text(rationale)
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            } else if entry.sets.first?.isFromHistory == true {
                Text("PRE-FILLED FROM LAST SESSION")
                    .font(.Tokens.micro)
                    .tracking(1.0)
                    .foregroundStyle(ColorTokens.text3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            Rectangle()
                .fill(ColorTokens.divider)
                .frame(height: 0.5)

            // Column headers based on input mode
            switch inputMode {
            case .weightReps:
                setHeaderRow(columns: [("SET", 32), ("WEIGHT", 0), ("REPS", 0), ("RPE", 48)])
            case .repsOnly:
                setHeaderRow(columns: [("SET", 32), ("REPS", 0), ("RPE", 48)])
            case .distanceDuration:
                setHeaderRow(columns: [("SET", 32), ("DIST (m)", 0), ("TIME (s)", 0), ("RPE", 48)])
            case .durationOnly:
                setHeaderRow(columns: [("SET", 32), ("TIME (min)", 0), ("RPE", 48)])
            }

            ForEach($entry.sets) { $set in
                SetEntryRow(
                    set: $set,
                    index: entry.sets.firstIndex(where: { $0.id == set.id }) ?? 0,
                    inputMode: inputMode
                )
                Rectangle()
                    .fill(ColorTokens.divider)
                    .frame(height: 0.5)
            }

            Button {
                entry.sets.append(SetDraft())
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(ColorTokens.surface)
    }

    private func setHeaderRow(columns: [(String, CGFloat)]) -> some View {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Set Entry Row

struct SetEntryRow: View {
    @Binding var set: SetDraft
    let index: Int
    var inputMode: ExerciseInputMode = .weightReps

    private var weightPlaceholder: String {
        if let t = set.targetWeightKg { return String(format: "%.0f", t) }
        return "kg"
    }

    private var repsPlaceholder: String {
        if let t = set.targetReps { return "\(t)" }
        return "reps"
    }

    private var rpePlaceholder: String {
        if let t = set.targetRPE { return String(format: "%.0f", t) }
        return "RPE"
    }

    var body: some View {
        HStack {
            Text("\(index + 1)")
                .frame(width: 32)
                .font(.Tokens.label)
                .foregroundStyle(set.isWarmup ? ColorTokens.zoneCaution : ColorTokens.text2)

            switch inputMode {
            case .weightReps:
                TextField(weightPlaceholder, value: $set.weightKg, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)

                TextField(repsPlaceholder, value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)

                TextField(rpePlaceholder, value: $set.rpe, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 48)

            case .repsOnly:
                TextField(repsPlaceholder, value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)

                TextField(rpePlaceholder, value: $set.rpe, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 48)

            case .distanceDuration:
                TextField("m", value: $set.distanceMeters, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)

                TextField("sec", value: $set.durationSeconds, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)

                TextField(rpePlaceholder, value: $set.rpe, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 48)

            case .durationOnly:
                TextField("min", value: $set.durationSeconds, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)

                TextField(rpePlaceholder, value: $set.rpe, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 48)
            }
        }
        .font(.Tokens.label)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
