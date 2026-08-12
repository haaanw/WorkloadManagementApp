import XCTest
@testable import workload_management

@MainActor
final class ActiveWorkoutViewStateTests: XCTestCase {

    func testActiveWorkoutViewStateOwnsHeroAndDockCopy() {
        var completedSet = SetDraft()
        completedSet.isDone = true
        var entry = ExerciseEntryDraft(exerciseName: "Back Squat", exerciseCategory: .compound)
        entry.sets = [completedSet, SetDraft()]

        let state = ActiveWorkoutViewState.make(
            sessionTitle: "Leg Day",
            sessionRPE: 7.4,
            entries: [entry],
            hasUnsavedChanges: true,
            isSaving: false
        )

        XCTAssertEqual(state.heroKicker, "Active Workout")
        XCTAssertEqual(state.sessionTitle, "Leg Day")
        XCTAssertEqual(state.heroBody, "1 / 2 sets done · RPE 7")
        XCTAssertEqual(state.finishActionTitle, "Finish · 1/2 sets")
        XCTAssertEqual(state.finishAccessibilityValue, "1 of 2 sets completed")
        XCTAssertEqual(state.addExerciseActionTitle, "Add Exercise")
        XCTAssertEqual(state.addExerciseAccessibilityIdentifier, "activeWorkout.addExercise")
        XCTAssertTrue(state.hasExercises)
    }

    func testSessionStateFormatsElapsedAndSettingsRows() {
        let state = ActiveWorkoutSessionState.make(
            sessionName: "Tempo Run",
            sportType: .running,
            sessionType: .cardio,
            elapsedSeconds: 75,
            locale: Locale(identifier: "en_US")
        )

        XCTAssertEqual(state.sectionTitle, "Session")
        XCTAssertEqual(state.sessionNameTitle, "Session Name")
        XCTAssertEqual(state.sessionNamePlaceholder, "Optional")
        XCTAssertEqual(state.sessionNameValue, "Tempo Run")
        XCTAssertEqual(state.elapsedLabel, "Elapsed")
        XCTAssertEqual(state.elapsedValue, "1m")
        XCTAssertEqual(state.elapsedDetail, "Session time")
        XCTAssertEqual(state.settingsTitle, "Session Settings")
        XCTAssertEqual(state.settingsValue, "Running · Cardio")
        XCTAssertEqual(state.settingsAccessibilityIdentifier, "activeWorkout.sessionSettings")
    }

    func testExerciseBlockStateFormatsDetailProgressAndActions() {
        var entry = ExerciseEntryDraft(
            exerciseName: "Back Squat",
            exerciseCategory: .compound,
            muscleGroup: .legs
        )
        entry.groupName = "Strength A"
        entry.sets = [
            SetDraft(isDone: true),
            SetDraft()
        ]

        let state = ActiveWorkoutExerciseBlockState.make(entry: entry, entryIndex: 2)

        XCTAssertEqual(state.title, "Back Squat")
        XCTAssertEqual(state.detail, "Compound · Legs · Strength A")
        XCTAssertEqual(state.progressText, "1 / 2 sets")
        XCTAssertEqual(state.progressAccessibilityIdentifier, "activeWorkout.exerciseProgress.2")
        XCTAssertEqual(state.actions.map(\.title), ["Add Set", "Repeat Last", "Remove"])
        XCTAssertEqual(state.actions.map(\.accessibilityIdentifier), [
            "activeWorkout.addSet.2",
            "activeWorkout.repeatLast.2",
            "activeWorkout.removeExercise.2"
        ])
    }

    func testSetInputFieldsForStrengthUseWeightRepsAndRPE() throws {
        var set = SetDraft(targetReps: 5, targetWeightKg: 100, targetRPE: 8)
        set.weightKg = 90
        set.reps = 3

        let state = ActiveWorkoutSetInputFieldsState.make(
            set: set,
            category: .compound,
            weightUnit: .kg,
            entryIndex: 1,
            setIndex: 2
        )

        XCTAssertEqual(state.fields.map(\.kind), [.weight, .reps, .rpe])
        XCTAssertEqual(state.fields.map(\.title), ["kg", "Reps", "RPE"])
        try assertDecimal(state.fields[0], value: 90, placeholder: 100, step: 2.5, closedRange: nil)
        try assertInteger(state.fields[1], value: 3, placeholder: 5, step: 1, closedRange: nil)
        try assertDecimal(state.fields[2], value: nil, placeholder: 8, step: 0.5, closedRange: 1...10)
        XCTAssertEqual(state.fields[0].accessibilityIdentifier, "activeWorkout.field.weight.1.2")
    }

    func testSetInputFieldsForRIRTemplateSuppressRPE() throws {
        let set = SetDraft(targetReps: 5, targetWeightKg: 100, targetRIR: 2)

        let state = ActiveWorkoutSetInputFieldsState.make(
            set: set,
            category: .compound,
            weightUnit: .kg,
            entryIndex: 0,
            setIndex: 0
        )

        XCTAssertEqual(state.fields.map(\.kind), [.weight, .reps, .rir])
        XCTAssertEqual(state.fields.map(\.title), ["kg", "Reps", "RIR"])
        try assertInteger(state.fields[2], value: nil, placeholder: 2, step: 1, closedRange: 0...10)
        XCTAssertEqual(state.fields[2].accessibilityIdentifier, "activeWorkout.field.rir.0.0")
    }

    func testSetInputFieldsForCardioUseDistanceDurationAndRPE() throws {
        let set = SetDraft(
            targetRPE: 6,
            targetDistanceMeters: 5000,
            targetDurationSeconds: 1500
        )

        let state = ActiveWorkoutSetInputFieldsState.make(
            set: set,
            category: .cardio,
            weightUnit: .kg,
            entryIndex: 0,
            setIndex: 1
        )

        XCTAssertEqual(state.fields.map(\.kind), [.distance, .duration, .rpe])
        XCTAssertEqual(state.fields.map(\.title), ["Km", "Min", "RPE"])
        try assertDecimal(state.fields[0], value: nil, placeholder: 5, step: 0.5, closedRange: nil)
        try assertInteger(state.fields[1], value: nil, placeholder: 25, step: 5, closedRange: nil)
        try assertDecimal(state.fields[2], value: nil, placeholder: 6, step: 0.5, closedRange: 1...10)
    }

    func testFinishWorkoutStateShowsTemplateFieldOnlyWhenNeeded() {
        let plain = FinishWorkoutViewState.make(
            sessionName: "Leg Day",
            sportType: .lifting,
            rpe: 8.6,
            saveAsTemplate: false,
            templateName: "Leg Template"
        )

        XCTAssertEqual(plain.navigationTitle, "Finish Workout")
        XCTAssertEqual(plain.keepEditingTitle, "Keep Editing")
        XCTAssertEqual(plain.commitActionTitle, "Finish Workout")
        XCTAssertEqual(plain.commitAccessibilityIdentifier, "finishWorkout.commit")
        XCTAssertEqual(plain.heroKicker, "Lifting")
        XCTAssertEqual(plain.heroTitle, "RPE 8")
        XCTAssertEqual(plain.heroBody, "Leg Day")
        XCTAssertEqual(plain.stateText, "Ready to save workout at RPE 8")
        XCTAssertFalse(plain.showsTemplateName)

        let template = FinishWorkoutViewState.make(
            sessionName: "Leg Day",
            sportType: .lifting,
            rpe: 8,
            saveAsTemplate: true,
            templateName: "Leg Template"
        )

        XCTAssertEqual(template.stateText, "Ready to save workout and template at RPE 8")
        XCTAssertTrue(template.showsTemplateName)
        XCTAssertEqual(template.templateNameTitle, "Template Name")
        XCTAssertEqual(template.templateNameValue, "Leg Template")
        XCTAssertEqual(template.templateNamePlaceholder, "Leg Day")
        XCTAssertEqual(template.templateNameAccessibilityIdentifier, "finishWorkout.templateName")
    }

    func testPostSaveFeedbackIncludesTemplateAndWarningState() {
        let result = WorkoutPipeline.PipelineResult(
            snapshot: WorkloadCalculator.WorkloadResult(date: .now, atl: 0, ctl: 0, acwr: 0, tsb: 0),
            newPRs: [PersonalRecord(exerciseName: "Back Squat", value: 140)],
            weeklyVolume: 0,
            spikeAlert: WorkloadCalculator.SpikeAlert(
                sessionTSS: 220,
                averageTSS: 90,
                ratio: 2.4,
                severity: .high
            )
        )

        let feedback = WorkoutPostSaveFeedback.make(result: result, templateSaved: true)

        XCTAssertEqual(feedback.navigationTitle, "Saved")
        XCTAssertEqual(feedback.heroKicker, "Workout")
        XCTAssertEqual(feedback.title, "Session Saved")
        XCTAssertEqual(feedback.summary, "Saved with a load warning.")
        XCTAssertEqual(feedback.doneActionTitle, "Done")
        XCTAssertEqual(feedback.doneAccessibilityIdentifier, "workoutPostSave.done")
        XCTAssertEqual(feedback.doneAccessibilityValue, "Workout saved")
        XCTAssertTrue(feedback.hasWarning)
        XCTAssertEqual(feedback.items.map(\.identifier), [
            "workoutPostSave.item.saved",
            "workoutPostSave.item.template",
            "workoutPostSave.item.pr",
            "workoutPostSave.item.spike"
        ])
        XCTAssertEqual(feedback.items[2].title, "1 new PR")
        XCTAssertEqual(feedback.items[2].detail, "Back Squat")
        XCTAssertEqual(feedback.items[3].detail, "Session load 220 vs recent 90. Add recovery if needed.")
        XCTAssertEqual(feedback.warningLabel, "Warning")
    }

    func testSessionSettingsStateOwnsRowsAndActions() {
        let state = ActiveWorkoutSessionSettingsViewState.make(
            sportType: .running,
            sessionType: .cardio
        )

        XCTAssertEqual(state.navigationTitle, "Session Settings")
        XCTAssertEqual(state.cancelTitle, "Cancel")
        XCTAssertEqual(state.cancelAccessibilityIdentifier, "activeWorkout.settings.cancel")
        XCTAssertEqual(state.doneActionTitle, "Done")
        XCTAssertEqual(state.doneAccessibilityIdentifier, "activeWorkout.settings.done")
        XCTAssertEqual(state.heroKicker, "Session")
        XCTAssertEqual(state.heroTitle, "Settings")
        XCTAssertEqual(state.stateText, "Running - Cardio")
        XCTAssertEqual(state.stateAccessibilityIdentifier, "activeWorkout.settings.state")
        XCTAssertEqual(state.sportChoiceTitle, "Sport")
        XCTAssertEqual(state.sessionTypeChoiceTitle, "Session Type")
        XCTAssertEqual(state.sportRow.title, "Sport")
        XCTAssertEqual(state.sportRow.value, "Running")
        XCTAssertEqual(state.sportRow.accessibilityIdentifier, "activeWorkout.settings.sport")
        XCTAssertEqual(state.sportRow.accessibilityLabel, "Sport, Running")
        XCTAssertEqual(state.sessionTypeRow.title, "Type")
        XCTAssertEqual(state.sessionTypeRow.value, "Cardio")
        XCTAssertEqual(state.sessionTypeRow.accessibilityIdentifier, "activeWorkout.settings.type")
        XCTAssertEqual(state.sessionTypeRow.accessibilityLabel, "Type, Cardio")
    }

    func testExercisePickerStateFormatsRowsAndAvailableCount() {
        let exercises = [
            ExerciseDefinition(name: "Back Squat", category: .compound, muscleGroup: .quads),
            ExerciseDefinition(name: "Custom Carry", category: .drill, muscleGroup: nil, isCustom: true)
        ]

        let state = ExercisePickerViewState.make(
            sportType: .lifting,
            exercises: exercises
        )

        XCTAssertEqual(state.navigationTitle, "Exercise")
        XCTAssertEqual(state.cancelTitle, "Cancel")
        XCTAssertEqual(state.cancelAccessibilityIdentifier, "exercisePicker.cancel")
        XCTAssertEqual(state.heroKicker, "Lifting")
        XCTAssertEqual(state.heroTitle, "Add exercise")
        XCTAssertEqual(state.heroBody, "Choose the next movement for this session.")
        XCTAssertEqual(state.stateText, "2 movements available")
        XCTAssertEqual(state.stateAccessibilityIdentifier, "exercisePicker.state")
        XCTAssertEqual(state.rows.count, 2)
        XCTAssertEqual(state.rows[0].title, "Back Squat")
        XCTAssertEqual(state.rows[0].detail, "Compound · Quads")
        XCTAssertEqual(state.rows[0].accessibilityIdentifier, "exercisePicker.exercise")
        XCTAssertEqual(state.rows[0].accessibilityLabel, "Back Squat")
        XCTAssertEqual(state.rows[1].title, "Custom Carry")
        XCTAssertEqual(state.rows[1].detail, "Drill · Custom")
    }

    func testActiveWorkoutAlertStatesOwnSafetyPromptCopyAndRoles() {
        let locale = Locale(identifier: "en_US")

        let unsaved = ActiveWorkoutAlertState.unsavedChanges(locale: locale)
        XCTAssertEqual(unsaved.title, "Unsaved workout")
        XCTAssertEqual(unsaved.message, "Your changes have not been saved. Keep editing or discard this workout.")
        XCTAssertEqual(unsaved.actions.map(\.title), ["Keep Editing", "Discard Changes"])
        XCTAssertEqual(unsaved.actions.map(\.role), [.cancel, .destructive])

        let noDone = ActiveWorkoutAlertState.noCompletedSets(locale: locale)
        XCTAssertEqual(noDone.title, "No sets logged")
        XCTAssertEqual(noDone.message, "Nothing will be logged. Tap Log set to record sets, or discard this session?")
        XCTAssertEqual(noDone.actions.map(\.title), ["Cancel", "Discard session"])
        XCTAssertEqual(noDone.actions.map(\.role), [.cancel, .destructive])

        let saveFailure = ActiveWorkoutAlertState.saveFailure(
            errorDescription: "Disk full",
            locale: locale
        )
        XCTAssertEqual(saveFailure.title, "Could not save session")
        XCTAssertEqual(saveFailure.message, "Disk full")
        XCTAssertEqual(saveFailure.actions.map(\.title), ["OK"])
        XCTAssertEqual(saveFailure.actions.map(\.role), [.normal])
    }

    private func assertDecimal(
        _ field: ActiveWorkoutSetInputFieldsState.Field,
        value expectedValue: Double?,
        placeholder expectedPlaceholder: Double?,
        step expectedStep: Double?,
        closedRange expectedRange: ClosedRange<Double>?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        guard case let .decimal(value, placeholder, step, closedRange) = field.value else {
            XCTFail("Expected decimal field", file: file, line: line)
            return
        }
        XCTAssertEqual(value, expectedValue, file: file, line: line)
        XCTAssertEqual(placeholder, expectedPlaceholder, file: file, line: line)
        XCTAssertEqual(step, expectedStep, file: file, line: line)
        XCTAssertEqual(closedRange, expectedRange, file: file, line: line)
    }

    private func assertInteger(
        _ field: ActiveWorkoutSetInputFieldsState.Field,
        value expectedValue: Int?,
        placeholder expectedPlaceholder: Int?,
        step expectedStep: Int?,
        closedRange expectedRange: ClosedRange<Int>?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        guard case let .integer(value, placeholder, step, closedRange) = field.value else {
            XCTFail("Expected integer field", file: file, line: line)
            return
        }
        XCTAssertEqual(value, expectedValue, file: file, line: line)
        XCTAssertEqual(placeholder, expectedPlaceholder, file: file, line: line)
        XCTAssertEqual(step, expectedStep, file: file, line: line)
        XCTAssertEqual(closedRange, expectedRange, file: file, line: line)
    }
}
