import Foundation

enum AppContext: String, CaseIterable, Codable, Hashable {
    case athlete
    case coach

    var displayName: String {
        switch self {
        case .athlete: "Athlete"
        case .coach: "Coach"
        }
    }
}

// MARK: - Active Workout Draft Models

struct ExerciseEntryDraft: Identifiable {
    let id = UUID()
    var exerciseName: String
    var exerciseCategory: ExerciseCategory
    var muscleGroup: MuscleGroup?
    var groupName: String?
    var sets: [SetDraft] = [SetDraft()]
    var suggestionRationale: String?
    var progressionType: ProgressionEngine.ProgressionType?
    var progressionSuggestions: [ProgressionEngine.SetSuggestion]?
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
    var targetReps: Int? = nil
    var targetWeightKg: Double? = nil
    var targetRPE: Double? = nil
    var targetRIR: Int? = nil
    var targetDistanceMeters: Double? = nil
    var targetDurationSeconds: Int? = nil
    var plannedWeightKg: Double? = nil
    var plannedRPE: Double? = nil
    var isSuggestedAdjustment: Bool = false
    var verdictReason: String? = nil
    var lastSessionWeightKg: Double? = nil
    var lastSessionReps: Int? = nil
    var lastSessionDistanceMeters: Double? = nil
    var lastSessionDurationSeconds: Int? = nil
    var isFromHistory: Bool = false
    var isDone: Bool = false
    var isSkipped: Bool = false
}

struct ActiveWorkoutViewState: Equatable {
    var heroKicker: String
    var sessionTitle: String
    var heroBody: String
    var completedSetCount: Int
    var totalSetCount: Int
    var exerciseCount: Int
    var hasUnsavedChanges: Bool
    var isSaving: Bool
    var finishActionTitle: String
    var finishAccessibilityValue: String
    var addExerciseActionTitle: String
    var addExerciseAccessibilityIdentifier: String
    var emptyTitle: String
    var emptyBody: String

    var hasExercises: Bool {
        exerciseCount > 0
    }

    static func make(
        sessionTitle: String,
        sessionRPE: Double,
        entries: [ExerciseEntryDraft],
        hasUnsavedChanges: Bool,
        isSaving: Bool
    ) -> ActiveWorkoutViewState {
        let totalSetCount = entries.reduce(0) { $0 + $1.sets.count }
        let completedSetCount = entries.reduce(0) { $0 + $1.sets.filter(\.isDone).count }

        return ActiveWorkoutViewState(
            heroKicker: "Active Workout",
            sessionTitle: sessionTitle,
            heroBody: "\(completedSetCount) / \(totalSetCount) sets done · RPE \(Int(sessionRPE))",
            completedSetCount: completedSetCount,
            totalSetCount: totalSetCount,
            exerciseCount: entries.count,
            hasUnsavedChanges: hasUnsavedChanges,
            isSaving: isSaving,
            finishActionTitle: isSaving ? "Saving..." : "Finish · \(completedSetCount)/\(totalSetCount) sets",
            finishAccessibilityValue: "\(completedSetCount) of \(totalSetCount) sets completed",
            addExerciseActionTitle: "Add Exercise",
            addExerciseAccessibilityIdentifier: "activeWorkout.addExercise",
            emptyTitle: "No exercises yet",
            emptyBody: "Add an exercise, enter the work that was actually completed, then finish the session."
        )
    }
}

struct ActiveWorkoutSessionState: Equatable {
    var sectionTitle: String
    var sessionNameTitle: String
    var sessionNamePlaceholder: String
    var sessionNameValue: String
    var elapsedLabel: String
    var elapsedValue: String
    var elapsedDetail: String
    var settingsTitle: String
    var settingsValue: String
    var settingsAccessibilityIdentifier: String

    static func make(
        sessionName: String,
        sportType: SportType,
        sessionType: SessionType,
        elapsedSeconds: Int,
        locale: Locale
    ) -> ActiveWorkoutSessionState {
        ActiveWorkoutSessionState(
            sectionTitle: "Session",
            sessionNameTitle: "Session Name",
            sessionNamePlaceholder: "Optional",
            sessionNameValue: sessionName,
            elapsedLabel: "Elapsed",
            elapsedValue: Date.durationString(seconds: elapsedSeconds, locale: locale),
            elapsedDetail: "Session time",
            settingsTitle: "Session Settings",
            settingsValue: "\(sportType.displayName) · \(sessionType.displayName)",
            settingsAccessibilityIdentifier: "activeWorkout.sessionSettings"
        )
    }
}

struct ActiveWorkoutExerciseBlockState: Equatable {
    struct Action: Equatable {
        var title: String
        var accessibilityIdentifier: String
    }

    var title: String
    var detail: String
    var progressText: String
    var progressAccessibilityIdentifier: String
    var actions: [Action]

    static func make(entry: ExerciseEntryDraft, entryIndex: Int) -> ActiveWorkoutExerciseBlockState {
        let detailParts = [
            entry.exerciseCategory.displayName,
            entry.muscleGroup?.displayName,
            entry.groupName
        ]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
        let completedSetCount = entry.sets.filter(\.isDone).count

        return ActiveWorkoutExerciseBlockState(
            title: entry.exerciseName,
            detail: detailParts.isEmpty ? entry.exerciseCategory.displayName : detailParts.joined(separator: " · "),
            progressText: "\(completedSetCount) / \(entry.sets.count) sets",
            progressAccessibilityIdentifier: "activeWorkout.exerciseProgress.\(entryIndex)",
            actions: [
                Action(
                    title: "Add Set",
                    accessibilityIdentifier: "activeWorkout.addSet.\(entryIndex)"
                ),
                Action(
                    title: "Repeat Last",
                    accessibilityIdentifier: "activeWorkout.repeatLast.\(entryIndex)"
                ),
                Action(
                    title: "Remove",
                    accessibilityIdentifier: "activeWorkout.removeExercise.\(entryIndex)"
                )
            ]
        )
    }
}

struct ActiveWorkoutSetInputFieldsState: Equatable {
    struct Field: Equatable {
        enum Kind: Equatable {
            case weight
            case reps
            case distance
            case duration
            case rpe
            case rir
        }

        enum Value: Equatable {
            case decimal(value: Double?, placeholder: Double?, step: Double?, closedRange: ClosedRange<Double>?)
            case integer(value: Int?, placeholder: Int?, step: Int?, closedRange: ClosedRange<Int>?)
        }

        var kind: Kind
        var title: String
        var accessibilityIdentifier: String
        var value: Value
    }

    var fields: [Field]

    static func make(
        set: SetDraft,
        category: ExerciseCategory,
        weightUnit: WeightUnit,
        entryIndex: Int,
        setIndex: Int
    ) -> ActiveWorkoutSetInputFieldsState {
        var fields: [Field] = []

        switch category.inputMode {
        case .weightReps:
            fields.append(Field(
                kind: .weight,
                title: weightUnit.displayName,
                accessibilityIdentifier: identifier("weight", entryIndex: entryIndex, setIndex: setIndex),
                value: .decimal(
                    value: displayWeight(set.weightKg, weightUnit: weightUnit),
                    placeholder: displayWeight(set.targetWeightKg, weightUnit: weightUnit),
                    step: weightUnit == .kg ? 2.5 : 5,
                    closedRange: nil
                )
            ))
            fields.append(repsField(set: set, entryIndex: entryIndex, setIndex: setIndex))
        case .repsOnly:
            fields.append(repsField(set: set, entryIndex: entryIndex, setIndex: setIndex))
        case .distanceDuration:
            fields.append(Field(
                kind: .distance,
                title: "Km",
                accessibilityIdentifier: identifier("distance", entryIndex: entryIndex, setIndex: setIndex),
                value: .decimal(
                    value: set.distanceMeters.map { $0 / 1000 },
                    placeholder: set.targetDistanceMeters.map { $0 / 1000 },
                    step: 0.5,
                    closedRange: nil
                )
            ))
            fields.append(Field(
                kind: .duration,
                title: "Min",
                accessibilityIdentifier: identifier("duration", entryIndex: entryIndex, setIndex: setIndex),
                value: .integer(
                    value: set.durationSeconds.map { $0 / 60 },
                    placeholder: set.targetDurationSeconds.map { $0 / 60 },
                    step: 5,
                    closedRange: nil
                )
            ))
        case .durationOnly:
            fields.append(Field(
                kind: .duration,
                title: "Min",
                accessibilityIdentifier: identifier("duration", entryIndex: entryIndex, setIndex: setIndex),
                value: .integer(
                    value: set.durationSeconds.map { $0 / 60 },
                    placeholder: set.targetDurationSeconds.map { $0 / 60 },
                    step: 5,
                    closedRange: nil
                )
            ))
        }

        fields.append(effortField(set: set, entryIndex: entryIndex, setIndex: setIndex))
        return ActiveWorkoutSetInputFieldsState(fields: fields)
    }

    private static func repsField(set: SetDraft, entryIndex: Int, setIndex: Int) -> Field {
        Field(
            kind: .reps,
            title: "Reps",
            accessibilityIdentifier: identifier("reps", entryIndex: entryIndex, setIndex: setIndex),
            value: .integer(
                value: set.reps,
                placeholder: set.targetReps,
                step: 1,
                closedRange: nil
            )
        )
    }

    private static func effortField(set: SetDraft, entryIndex: Int, setIndex: Int) -> Field {
        if set.targetRIR != nil && set.targetRPE == nil {
            return Field(
                kind: .rir,
                title: "RIR",
                accessibilityIdentifier: identifier("rir", entryIndex: entryIndex, setIndex: setIndex),
                value: .integer(
                    value: set.rir,
                    placeholder: set.targetRIR,
                    step: 1,
                    closedRange: 0...10
                )
            )
        }

        return Field(
            kind: .rpe,
            title: "RPE",
            accessibilityIdentifier: identifier("rpe", entryIndex: entryIndex, setIndex: setIndex),
            value: .decimal(
                value: set.rpe,
                placeholder: set.targetRPE,
                step: 0.5,
                closedRange: 1...10
            )
        )
    }

    private static func displayWeight(_ weightKg: Double?, weightUnit: WeightUnit) -> Double? {
        weightKg.map { $0 / weightUnit.conversionToKg }
    }

    private static func identifier(_ field: String, entryIndex: Int, setIndex: Int) -> String {
        "activeWorkout.field.\(field).\(entryIndex).\(setIndex)"
    }
}

struct FinishWorkoutViewState: Equatable {
    var navigationTitle: String
    var keepEditingTitle: String
    var keepEditingAccessibilityIdentifier: String
    var commitActionTitle: String
    var commitAccessibilityIdentifier: String
    var commitAccessibilityValue: String
    var heroKicker: String
    var heroTitle: String
    var heroBody: String
    var stateText: String
    var stateAccessibilityIdentifier: String
    var rpeLabel: String
    var rpeAccessibilityIdentifier: String
    var saveAsTemplateTitle: String
    var saveAsTemplateAccessibilityIdentifier: String
    var showsTemplateName: Bool
    var templateNameTitle: String
    var templateNameValue: String
    var templateNamePlaceholder: String
    var templateNameAccessibilityIdentifier: String

    static func make(
        sessionName: String,
        sportType: SportType,
        rpe: Double,
        saveAsTemplate: Bool,
        templateName: String
    ) -> FinishWorkoutViewState {
        let target = saveAsTemplate ? "workout and template" : "workout"
        return FinishWorkoutViewState(
            navigationTitle: "Finish Workout",
            keepEditingTitle: "Keep Editing",
            keepEditingAccessibilityIdentifier: "finishWorkout.keepEditing",
            commitActionTitle: "Finish Workout",
            commitAccessibilityIdentifier: "finishWorkout.commit",
            commitAccessibilityValue: "Ready to save \(target) at RPE \(Int(rpe))",
            heroKicker: sportType.displayName,
            heroTitle: "RPE \(Int(rpe))",
            heroBody: sessionName,
            stateText: "Ready to save \(target) at RPE \(Int(rpe))",
            stateAccessibilityIdentifier: "finishWorkout.state",
            rpeLabel: "Session RPE",
            rpeAccessibilityIdentifier: "finishWorkout.rpe",
            saveAsTemplateTitle: "Save as Template",
            saveAsTemplateAccessibilityIdentifier: "finishWorkout.saveAsTemplate",
            showsTemplateName: saveAsTemplate,
            templateNameTitle: "Template Name",
            templateNameValue: templateName,
            templateNamePlaceholder: sessionName,
            templateNameAccessibilityIdentifier: "finishWorkout.templateName"
        )
    }
}

struct WorkoutPostSaveFeedback: Equatable {
    struct Item: Equatable {
        let identifier: String
        let title: String
        let detail: String
        let isWarning: Bool
    }

    let navigationTitle: String
    let heroKicker: String
    let title: String
    let summary: String
    let doneActionTitle: String
    let doneAccessibilityIdentifier: String
    let doneAccessibilityValue: String
    let warningLabel: String
    let items: [Item]

    var hasWarning: Bool {
        items.contains { $0.isWarning }
    }

    static func make(
        result: WorkoutPipeline.PipelineResult? = nil,
        templateSaved: Bool
    ) -> WorkoutPostSaveFeedback {
        var items: [Item] = [
            Item(
                identifier: "workoutPostSave.item.saved",
                title: "Workout logged",
                detail: "Your completed sets were saved and workload was updated.",
                isWarning: false
            )
        ]

        if templateSaved {
            items.append(Item(
                identifier: "workoutPostSave.item.template",
                title: "Template saved",
                detail: "This session is available from the template picker.",
                isWarning: false
            ))
        }

        if let result {
            if !result.newPRs.isEmpty {
                let count = result.newPRs.count
                let suffix = count == 1 ? "" : "s"
                items.append(Item(
                    identifier: "workoutPostSave.item.pr",
                    title: "\(count) new PR\(suffix)",
                    detail: result.newPRs.map(\.exerciseName).prefix(3).joined(separator: " · "),
                    isWarning: false
                ))
            }

            if let spike = result.spikeAlert {
                items.append(Item(
                    identifier: "workoutPostSave.item.spike",
                    title: "Load spike",
                    detail: "Session load \(Int(spike.sessionTSS)) vs recent \(Int(spike.averageTSS)). Add recovery if needed.",
                    isWarning: true
                ))
            }
        }

        let summary: String
        if items.contains(where: { $0.identifier == "workoutPostSave.item.spike" }) {
            summary = "Saved with a load warning."
        } else if items.count > 1 {
            summary = "Saved with follow-up notes."
        } else {
            summary = "Saved and ready for your next session."
        }

        return WorkoutPostSaveFeedback(
            navigationTitle: "Saved",
            heroKicker: "Workout",
            title: "Session Saved",
            summary: summary,
            doneActionTitle: "Done",
            doneAccessibilityIdentifier: "workoutPostSave.done",
            doneAccessibilityValue: "Workout saved",
            warningLabel: "Warning",
            items: items
        )
    }
}

struct ActiveWorkoutSessionSettingsViewState: Equatable {
    struct Row: Equatable {
        var title: String
        var value: String
        var accessibilityIdentifier: String
        var accessibilityLabel: String
    }

    var navigationTitle: String
    var cancelTitle: String
    var cancelAccessibilityIdentifier: String
    var doneActionTitle: String
    var doneAccessibilityIdentifier: String
    var heroKicker: String
    var heroTitle: String
    var heroBody: String
    var stateText: String
    var stateAccessibilityIdentifier: String
    var sportChoiceTitle: String
    var sessionTypeChoiceTitle: String
    var sportRow: Row
    var sessionTypeRow: Row

    static func make(
        sportType: SportType,
        sessionType: SessionType
    ) -> ActiveWorkoutSessionSettingsViewState {
        let stateText = "\(sportType.displayName) - \(sessionType.displayName)"
        return ActiveWorkoutSessionSettingsViewState(
            navigationTitle: "Session Settings",
            cancelTitle: "Cancel",
            cancelAccessibilityIdentifier: "activeWorkout.settings.cancel",
            doneActionTitle: "Done",
            doneAccessibilityIdentifier: "activeWorkout.settings.done",
            heroKicker: "Session",
            heroTitle: "Settings",
            heroBody: "Sport and session type live here so the workout stays focused.",
            stateText: stateText,
            stateAccessibilityIdentifier: "activeWorkout.settings.state",
            sportChoiceTitle: "Sport",
            sessionTypeChoiceTitle: "Session Type",
            sportRow: Row(
                title: "Sport",
                value: sportType.displayName,
                accessibilityIdentifier: "activeWorkout.settings.sport",
                accessibilityLabel: "Sport, \(sportType.displayName)"
            ),
            sessionTypeRow: Row(
                title: "Type",
                value: sessionType.displayName,
                accessibilityIdentifier: "activeWorkout.settings.type",
                accessibilityLabel: "Type, \(sessionType.displayName)"
            )
        )
    }
}

struct ExercisePickerViewState: Equatable {
    struct Row: Equatable {
        var title: String
        var detail: String
        var accessibilityIdentifier: String
        var accessibilityLabel: String
    }

    var navigationTitle: String
    var cancelTitle: String
    var cancelAccessibilityIdentifier: String
    var heroKicker: String
    var heroTitle: String
    var heroBody: String
    var stateText: String
    var stateAccessibilityIdentifier: String
    var rows: [Row]

    static func make(
        sportType: SportType,
        exercises: [ExerciseDefinition]
    ) -> ExercisePickerViewState {
        ExercisePickerViewState(
            navigationTitle: "Exercise",
            cancelTitle: "Cancel",
            cancelAccessibilityIdentifier: "exercisePicker.cancel",
            heroKicker: sportType.displayName,
            heroTitle: "Add exercise",
            heroBody: "Choose the next movement for this session.",
            stateText: "\(exercises.count) movements available",
            stateAccessibilityIdentifier: "exercisePicker.state",
            rows: exercises.map { exercise in
                Row(
                    title: exercise.name,
                    detail: exerciseDetail(exercise),
                    accessibilityIdentifier: "exercisePicker.exercise",
                    accessibilityLabel: exercise.name
                )
            }
        )
    }

    private static func exerciseDetail(_ exercise: ExerciseDefinition) -> String {
        [
            exercise.category.displayName,
            exercise.muscleGroup?.displayName,
            exercise.isCustom ? "Custom" : nil
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}

struct ActiveWorkoutAlertState: Equatable {
    enum ActionRole: Equatable {
        case normal
        case cancel
        case destructive
    }

    struct Action: Equatable {
        var title: String
        var role: ActionRole
    }

    var title: String
    var message: String?
    var actions: [Action]

    static func unsavedChanges(locale: Locale) -> ActiveWorkoutAlertState {
        ActiveWorkoutAlertState(
            title: LocalePinnedStrings.localized(
                "workout.unsaved.title",
                defaultValue: "Unsaved workout",
                locale: locale
            ),
            message: LocalePinnedStrings.localized(
                "workout.unsaved.message",
                defaultValue: "Your changes have not been saved. Keep editing or discard this workout.",
                locale: locale
            ),
            actions: [
                Action(
                    title: LocalePinnedStrings.localized(
                        "action.keepEditing",
                        defaultValue: "Keep Editing",
                        locale: locale
                    ),
                    role: .cancel
                ),
                Action(
                    title: LocalePinnedStrings.localized(
                        "action.discardChanges",
                        defaultValue: "Discard Changes",
                        locale: locale
                    ),
                    role: .destructive
                )
            ]
        )
    }

    static func noCompletedSets(locale: Locale) -> ActiveWorkoutAlertState {
        ActiveWorkoutAlertState(
            title: LocalePinnedStrings.localized(
                "workout.save.noDone.title",
                defaultValue: "No sets marked done",
                locale: locale
            ),
            message: LocalePinnedStrings.localized(
                "workout.save.noDone.message",
                defaultValue: "Nothing will be logged. Mark sets done to record them, or discard this session?",
                locale: locale
            ),
            actions: [
                Action(
                    title: LocalePinnedStrings.localized(
                        "action.cancel",
                        defaultValue: "Cancel",
                        locale: locale
                    ),
                    role: .cancel
                ),
                Action(
                    title: LocalePinnedStrings.localized(
                        "workout.save.noDone.discard",
                        defaultValue: "Discard session",
                        locale: locale
                    ),
                    role: .destructive
                )
            ]
        )
    }

    static func saveFailure(errorDescription: String, locale: Locale) -> ActiveWorkoutAlertState {
        ActiveWorkoutAlertState(
            title: LocalePinnedStrings.localized(
                "workout.save.failed.title",
                defaultValue: "Could not save session",
                locale: locale
            ),
            message: errorDescription,
            actions: [
                Action(
                    title: LocalePinnedStrings.localized(
                        "action.ok",
                        defaultValue: "OK",
                        locale: locale
                    ),
                    role: .normal
                )
            ]
        )
    }
}
