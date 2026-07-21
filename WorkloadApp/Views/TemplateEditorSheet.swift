import SwiftUI
import SwiftData

struct TemplateEditorSheet: View {
    let coachId: UUID
    let existingTemplate: WorkoutTemplate?
    let onSaved: ((WorkoutTemplate) -> Void)?

    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var templateName = ""
    @State private var sportType: SportType = .lifting
    @State private var sessionType: SessionType = .strength
    @State private var notes = ""
    @State private var groups: [GroupDraft] = [GroupDraft(groupName: "Main")]
    @State private var scheduledDays: [Int] = []
    @State private var isFavorite: Bool = false
    @State private var showExercisePicker = false
    @State private var activeGroupIndex: Int = 0
    @State private var saveError: String?

    init(
        coachId: UUID,
        existingTemplate: WorkoutTemplate?,
        onSaved: ((WorkoutTemplate) -> Void)? = nil
    ) {
        self.coachId = coachId
        self.existingTemplate = existingTemplate
        self.onSaved = onSaved
    }

    /// Convenience init for LLM import pre-fill (D-06)
    init(
        coachId: UUID,
        prefillName: String,
        prefillSportType: SportType,
        prefillSessionType: SessionType,
        prefillGroups: [GroupDraft],
        onSaved: ((WorkoutTemplate) -> Void)? = nil
    ) {
        self.coachId = coachId
        self.existingTemplate = nil
        self.onSaved = onSaved
        self._templateName = State(initialValue: prefillName)
        self._sportType = State(initialValue: prefillSportType)
        self._sessionType = State(initialValue: prefillSessionType)
        self._groups = State(initialValue: prefillGroups.isEmpty ? [GroupDraft(groupName: "Main")] : prefillGroups)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header fields
                    VStack(spacing: 16) {
                        TextField("template.field.name.placeholder", text: $templateName)
                            .textFieldStyle(SharpTextFieldStyle())

                        Picker("template.picker.sport", selection: $sportType) {
                            ForEach(SportType.allCases) { sport in
                                Text(sport.displayName).tag(sport)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("template.picker.type", selection: $sessionType) {
                            ForEach(SessionType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        TextField("template.field.notes.placeholder", text: $notes, axis: .vertical)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .textFieldStyle(SharpTextFieldStyle())
                            .lineLimit(2...4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(ColorTokens.surface)

                    // Schedule picker
                    Text("template.label.schedule")
                        .font(.Tokens.micro)
                        .tracking(0.9)
                        .textCase(.uppercase)
                        .foregroundStyle(ColorTokens.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    HStack(spacing: 8) {
                        ForEach(Array(zip([1, 2, 3, 4, 5, 6, 7], ["M", "T", "W", "T", "F", "S", "S"])), id: \.0) { value, label in
                            Button {
                                if scheduledDays.contains(value) {
                                    scheduledDays.removeAll { $0 == value }
                                } else {
                                    scheduledDays.append(value)
                                    scheduledDays.sort()
                                }
                            } label: {
                                Text(label)
                                    .font(.Tokens.label)
                                    .foregroundStyle(scheduledDays.contains(value) ? ColorTokens.text1 : ColorTokens.text2)
                                    .frame(width: 40, height: 40)
                                    .background(scheduledDays.contains(value) ? ColorTokens.surface : ColorTokens.background, in: RoundedRectangle(cornerRadius: CornerTokens.control))
                                    .overlay(RoundedRectangle(cornerRadius: CornerTokens.control).stroke(scheduledDays.contains(value) ? ColorTokens.text1 : ColorTokens.divider, lineWidth: 0.5))
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    // Favorite toggle
                    Toggle(isOn: $isFavorite) {
                        Text("template.label.favorite")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                    }
                    .toggleStyle(.design)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // Exercise groups
                    ForEach($groups) { $group in
                        let groupIdx = groups.firstIndex(where: { $0.id == group.id }) ?? 0
                        GroupEditorCard(
                            group: $group,
                            onAddExercise: {
                                activeGroupIndex = groupIdx
                                showExercisePicker = true
                            },
                            onDelete: groups.count > 1 ? {
                                groups.remove(at: groupIdx)
                            } : nil
                        )
                        Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                    }

                    // Add group button
                    Button {
                        let nextName = groups.count < 26
                            ? "Group \(Character(UnicodeScalar(65 + groups.count)!))"
                            : "Group \(groups.count + 1)"
                        groups.append(GroupDraft(groupName: nextName))
                    } label: {
                        Label("template.group.action.add", systemImage: "plus")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .background(ColorTokens.background)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

                    // Save error
                    if let saveError {
                        Text(saveError)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.zoneDanger)
                            .padding(16)
                    }
                }
            }
            .background(ColorTokens.background)
            .navigationTitle(existingTemplate == nil ? "template.nav.newTemplate" : "action.editTemplate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.save") { save() }
                        .font(.Tokens.label)
                        .foregroundStyle(
                            templateName.trimmingCharacters(in: .whitespaces).isEmpty ? ColorTokens.text3 : ColorTokens.text1
                        )
                        .disabled(templateName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(sportType: sportType) { name, category, muscle in
                    guard activeGroupIndex < groups.count else { return }
                    groups[activeGroupIndex].exercises.append(
                        ExerciseDraft(
                            exerciseName: name,
                            exerciseCategory: category,
                            muscleGroup: muscle
                        )
                    )
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let t = existingTemplate else { return }
        templateName = t.templateName
        sportType = t.sportType
        sessionType = t.sessionType
        notes = t.notes ?? ""
        scheduledDays = t.scheduledDays
        isFavorite = t.isFavorite
        groups = t.sortedGroups.map { group in
            var draft = GroupDraft(groupName: group.groupName)
            draft.exercises = group.sortedExercises.map { exercise in
                var exDraft = ExerciseDraft(
                    exerciseName: exercise.exerciseName,
                    exerciseCategory: exercise.exerciseCategory,
                    muscleGroup: exercise.muscleGroup
                )
                exDraft.sets = exercise.sortedSets.map { set in
                    TargetSetDraft(
                        targetReps: set.targetReps,
                        targetWeightKg: set.targetWeightKg,
                        targetDurationSeconds: set.targetDurationSeconds,
                        targetDistanceMeters: set.targetDistanceMeters,
                        targetRIR: set.targetRIR,
                        isWarmup: set.isWarmup
                    )
                }
                return exDraft
            }
            return draft
        }
        if groups.isEmpty { groups = [GroupDraft(groupName: "Main")] }
    }

    private func save() {
        let template: WorkoutTemplate
        if let existing = existingTemplate {
            template = existing
            template.templateName = templateName.trimmingCharacters(in: .whitespaces)
            template.sportType = sportType
            template.sessionType = sessionType
            template.notes = notes.isEmpty ? nil : notes
            template.updatedAt = .now
            // Snapshot then clear to avoid mutating during iteration (CR-01)
            let oldGroups = Array(template.groups)
            template.groups = []
            for group in oldGroups { modelContext.delete(group) }
        } else {
            template = WorkoutTemplate(
                coachId: coachId,
                templateName: templateName.trimmingCharacters(in: .whitespaces),
                sportType: sportType,
                sessionType: sessionType,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(template)
        }

        template.scheduledDays = scheduledDays
        template.isFavorite = isFavorite
        if existingTemplate == nil || existingTemplate?.isAthleteOwned == true {
            template.isAthleteOwned = true
            template.athleteId = coachId
        }

        // Build groups from drafts
        for (gIdx, gDraft) in groups.enumerated() {
            let group = ExerciseGroup(groupName: gDraft.groupName, orderIndex: gIdx)
            for (eIdx, eDraft) in gDraft.exercises.enumerated() {
                let exercise = TemplateExercise(
                    exerciseName: eDraft.exerciseName,
                    exerciseCategory: eDraft.exerciseCategory,
                    muscleGroup: eDraft.muscleGroup,
                    orderIndex: eIdx
                )
                for (sIdx, sDraft) in eDraft.sets.enumerated() {
                    let set = TemplateSet(
                        setIndex: sIdx,
                        targetReps: sDraft.targetReps,
                        targetWeightKg: sDraft.targetWeightKg,
                        targetDurationSeconds: sDraft.targetDurationSeconds,
                        targetDistanceMeters: sDraft.targetDistanceMeters,
                        targetRPE: nil,
                        targetRIR: sDraft.targetRIR,
                        isWarmup: sDraft.isWarmup
                    )
                    exercise.sets.append(set)
                }
                group.exercises.append(exercise)
            }
            template.groups.append(group)
        }

        do {
            try modelContext.save()
        } catch {
            print("Template save error: \(error)")
            saveError = "Couldn't save template. Please try again."
            return
        }

        Task {
            await container.syncService.pushWorkoutTemplates(
                context: modelContext, coachId: coachId
            )
        }

        onSaved?(template)
        dismiss()
    }
}

// MARK: - Group Editor Card

struct GroupEditorCard: View {
    @Binding var group: GroupDraft
    let onAddExercise: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            HStack {
                TextField("template.group.field.name.placeholder", text: $group.groupName)
                    .font(.Tokens.sectionHead)
                    .foregroundStyle(ColorTokens.text1)

                Spacer()

                if let onDelete {
                    Button { onDelete() } label: {
                        Image(systemName: "xmark")
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text3)
                    }
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)

            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

            // Exercises in this group
            ForEach($group.exercises) { $exercise in
                TemplateExerciseCard(exercise: $exercise)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            }

            // Add exercise to this group
            Button { onAddExercise() } label: {
                Label("action.addExercise", systemImage: "plus")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
            }
        }
        .background(ColorTokens.surface)
    }
}

// MARK: - Template Exercise Card

struct TemplateExerciseCard: View {
    @Binding var exercise: ExerciseDraft

    private var inputMode: ExerciseInputMode {
        exercise.exerciseCategory.inputMode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(exercise.exerciseName)
                    .font(.Tokens.body)
                    .foregroundStyle(ColorTokens.text1)
                Spacer()
                if let muscle = exercise.muscleGroup {
                    Text(muscle.displayName)
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Set headers — adapt to exercise category
            setHeaderRow
                .font(.Tokens.micro)
                .tracking(0.9)
                .foregroundStyle(ColorTokens.text3)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)

            ForEach($exercise.sets) { $set in
                let idx = exercise.sets.firstIndex(where: { $0.id == set.id }) ?? 0
                TargetSetRow(set: $set, index: idx, inputMode: inputMode)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            }

            Button {
                exercise.sets.append(TargetSetDraft())
            } label: {
                Label("set.action.add", systemImage: "plus")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var setHeaderRow: some View {
        HStack {
            Text("table.header.set")
                .frame(width: 32)
            switch inputMode {
            case .weightReps:
                Text("table.header.weight")
                    .frame(maxWidth: .infinity)
                Text("table.header.reps")
                    .frame(maxWidth: .infinity)
            case .repsOnly:
                Text("table.header.reps")
                    .frame(maxWidth: .infinity)
            case .distanceDuration:
                Text("exercise.label.distance")
                    .frame(maxWidth: .infinity)
                Text("exercise.label.duration")
                    .frame(maxWidth: .infinity)
            case .durationOnly:
                Text("exercise.label.duration")
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Target Set Row

struct TargetSetRow: View {
    @Binding var set: TargetSetDraft
    let index: Int
    let inputMode: ExerciseInputMode

    var body: some View {
        HStack {
            Text("\(index + 1)")
                .frame(width: 32)
                .font(.Tokens.label)
                .foregroundStyle(set.isWarmup ? ColorTokens.zoneCaution : ColorTokens.text2)

            switch inputMode {
            case .weightReps:
                TextField("kg", value: $set.targetWeightKg, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(SharpTextFieldStyle())
                    .frame(maxWidth: .infinity)

                TextField("reps", value: $set.targetReps, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(SharpTextFieldStyle())
                    .frame(maxWidth: .infinity)

            case .repsOnly:
                TextField("reps", value: $set.targetReps, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(SharpTextFieldStyle())
                    .frame(maxWidth: .infinity)

            case .distanceDuration:
                TextField("meters", value: $set.targetDistanceMeters, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(SharpTextFieldStyle())
                    .frame(maxWidth: .infinity)

                TextField("min", value: $set.targetDurationMinutes, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(SharpTextFieldStyle())
                    .frame(maxWidth: .infinity)

            case .durationOnly:
                TextField("min", value: $set.targetDurationMinutes, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(SharpTextFieldStyle())
                    .frame(maxWidth: .infinity)
            }
        }
        .font(.Tokens.label)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Draft Models (local state only)

struct GroupDraft: Identifiable {
    let id = UUID()
    var groupName: String
    var exercises: [ExerciseDraft] = []
}

struct ExerciseDraft: Identifiable {
    let id = UUID()
    var exerciseName: String
    var exerciseCategory: ExerciseCategory
    var muscleGroup: MuscleGroup?
    var sets: [TargetSetDraft] = [TargetSetDraft()]
}

struct TargetSetDraft: Identifiable {
    let id = UUID()
    var targetReps: Int? = nil
    var targetWeightKg: Double? = nil
    var targetDurationSeconds: Int? = nil
    var targetDistanceMeters: Double? = nil
    var targetRIR: Int? = nil
    var isWarmup: Bool = false

    /// Duration in minutes for UI display (stored as seconds internally)
    var targetDurationMinutes: Double? {
        get { targetDurationSeconds.map { Double($0) / 60.0 } }
        set { targetDurationSeconds = newValue.map { Int($0 * 60) } }
    }
}
