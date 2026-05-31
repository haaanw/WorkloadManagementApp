import SwiftUI
import SwiftData

struct TemplateEditorSheet: View {
    let coachId: UUID
    let existingTemplate: WorkoutTemplate?

    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var templateName = ""
    @State private var sportType: SportType = .lifting
    @State private var sessionType: SessionType = .strength
    @State private var notes = ""
    @State private var groups: [GroupDraft] = [GroupDraft(groupName: "Main")]
    @State private var showExercisePicker = false
    @State private var activeGroupIndex: Int = 0

    init(coachId: UUID, existingTemplate: WorkoutTemplate?) {
        self.coachId = coachId
        self.existingTemplate = existingTemplate
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header fields
                    VStack(spacing: 16) {
                        TextField("Template Name", text: $templateName)
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .textFieldStyle(.roundedBorder)

                        RadialPicker(selection: $sportType, title: "Sport")

                        RadialPicker(selection: $sessionType, title: "Type")

                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                            .font(.Tokens.label)
                            .foregroundStyle(ColorTokens.text2)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .background(ColorTokens.surface)

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
                        let nextName = "Group \(Character(UnicodeScalar(65 + min(groups.count, 25))!))"
                        groups.append(GroupDraft(groupName: nextName))
                    } label: {
                        Label("Add Group", systemImage: "plus")
                            .font(.Tokens.body)
                            .foregroundStyle(ColorTokens.text1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .background(ColorTokens.background)

                    Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
                }
            }
            .background(ColorTokens.background)
            .navigationTitle(existingTemplate == nil ? "New Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.Tokens.label)
                        .foregroundStyle(ColorTokens.text2)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.Tokens.label)
                        .foregroundStyle(
                            templateName.isEmpty ? ColorTokens.text3 : ColorTokens.text1
                        )
                        .disabled(templateName.isEmpty)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { name, category, muscle in
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
                        targetRPE: set.targetRPE,
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
            template.templateName = templateName
            template.sportType = sportType
            template.sessionType = sessionType
            template.notes = notes.isEmpty ? nil : notes
            template.updatedAt = .now
            // Remove old groups
            for group in template.groups { modelContext.delete(group) }
            template.groups = []
        } else {
            template = WorkoutTemplate(
                coachId: coachId,
                templateName: templateName,
                sportType: sportType,
                sessionType: sessionType,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(template)
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
                        targetRPE: sDraft.targetRPE,
                        targetRIR: sDraft.targetRIR,
                        isWarmup: sDraft.isWarmup
                    )
                    exercise.sets.append(set)
                }
                group.exercises.append(exercise)
            }
            template.groups.append(group)
        }

        try? modelContext.save()

        Task {
            await container.syncService.pushWorkoutTemplates(
                context: modelContext, coachId: coachId
            )
        }

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
                TextField("Group Name", text: $group.groupName)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Rectangle().fill(ColorTokens.divider).frame(height: 0.5)

            // Exercises in this group
            ForEach($group.exercises) { $exercise in
                TemplateExerciseCard(exercise: $exercise)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            }

            // Add exercise to this group
            Button { onAddExercise() } label: {
                Label("Add Exercise", systemImage: "plus")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
        .background(ColorTokens.surface)
    }
}

// MARK: - Template Exercise Card

struct TemplateExerciseCard: View {
    @Binding var exercise: ExerciseDraft

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

            // Set headers
            HStack {
                Text("coach.template.columnSet")
                    .frame(width: 32)
                Text("coach.template.columnWeight")
                    .frame(maxWidth: .infinity)
                Text("coach.template.columnReps")
                    .frame(maxWidth: .infinity)
                Text("coach.template.columnRPE")
                    .frame(width: 48)
            }
            .font(.Tokens.micro)
            .tracking(1.2)
            .foregroundStyle(ColorTokens.text3)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)

            ForEach($exercise.sets) { $set in
                let idx = exercise.sets.firstIndex(where: { $0.id == set.id }) ?? 0
                TargetSetRow(set: $set, index: idx)
                Rectangle().fill(ColorTokens.divider).frame(height: 0.5)
            }

            Button {
                exercise.sets.append(TargetSetDraft())
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.Tokens.label)
                    .foregroundStyle(ColorTokens.text3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Target Set Row

struct TargetSetRow: View {
    @Binding var set: TargetSetDraft
    let index: Int

    var body: some View {
        HStack {
            Text("\(index + 1)")
                .frame(width: 32)
                .font(.Tokens.label)
                .foregroundStyle(set.isWarmup ? ColorTokens.zoneCaution : ColorTokens.text2)

            TextField("kg", value: $set.targetWeightKg, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

            TextField("reps", value: $set.targetReps, format: .number)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

            TextField("RPE", value: $set.targetRPE, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 48)
        }
        .font(.Tokens.label)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
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
    var targetRPE: Double? = nil
    var targetRIR: Int? = nil
    var isWarmup: Bool = false
}
