import XCTest

/// Automated App Store screenshot capture.
///
/// Run on two simulators for both required device sizes:
///   - iPhone 15 Pro Max (6.7") -- required by ASO-03
///   - iPhone 11 Pro Max (6.5") -- required by ASO-03
///
/// Extract screenshots from xcresult bundle:
///   xcparse screenshots <path-to>.xcresult ~/Desktop/AppStoreScreenshots
///
final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Self-Coached Athlete Screenshots

    func test00_LoadingUsesUIKitInstrumentSurface() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_LOADING_MODE"], waitForTab: false)

        XCTAssertTrue(app.otherElements["app.loading.view"].waitForExistence(timeout: 10), "UIKit loading surface missing")
        XCTAssertTrue(app.staticTexts["app.loading"].waitForExistence(timeout: 5), "UIKit loading state label missing")
        XCTAssertTrue(app.staticTexts["Preparing Tonus"].waitForExistence(timeout: 5), "UIKit loading title missing")
    }

    func test01_Today() throws {
        launchAuthenticatedApp()
        XCTAssertTrue(app.buttons["today.primaryAction"].waitForExistence(timeout: 10), "Today primary action missing")
        sleep(2)
        saveScreenshot("01_Today")
    }

    func test01B_AppStoreV21BasketballScreenshots() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        XCTAssertTrue(app.descendants(matching: .any)["workoutLog.verdictCard"].waitForExistence(timeout: 10), "v2.1 verdict card missing")
        XCTAssertTrue(app.staticTexts["workoutLog.verdict.state"].waitForExistence(timeout: 10), "Verdict state missing")
        XCTAssertTrue(app.staticTexts["workoutLog.verdict.adjustedTopSet"].waitForExistence(timeout: 5), "Adjusted top set missing")
        XCTAssertTrue(app.descendants(matching: .any)["workoutLog.verdict.strikeZone"].waitForExistence(timeout: 5), "Strike-zone bar missing")
        XCTAssertTrue(app.staticTexts["workoutLog.verdict.reason"].waitForExistence(timeout: 5), "Verdict reason missing")
        saveScreenshot("AppStore_v21_01_VerdictMicrodose")

        saveScreenshot("AppStore_v21_02_StrikeZone")

        let nextMatch = app.descendants(matching: .any)["workoutLog.nextMatch"]
        if !nextMatch.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(nextMatch.waitForExistence(timeout: 10), "Next-match row missing")
        saveScreenshot("AppStore_v21_03_NextMatch")

        launchAuthenticatedApp()
        tapTab("tab.athlete.train")
        let startButton = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Workout start button not found")
        startButton.tap()
        let blankButton = app.buttons["templatePicker.startBlank"]
        XCTAssertTrue(blankButton.waitForExistence(timeout: 10), "Start blank button not found")
        blankButton.tap()
        let sessionSettings = app.buttons["activeWorkout.sessionSettings"]
        XCTAssertTrue(sessionSettings.waitForExistence(timeout: 10), "Session settings row missing")
        sessionSettings.tap()
        let typeRow = app.buttons["activeWorkout.settings.type"]
        XCTAssertTrue(typeRow.waitForExistence(timeout: 10), "Session type row missing")
        typeRow.tap()
        tapLocalizedButton(labels: ["Match", "比赛"])
        XCTAssertTrue(app.descendants(matching: .any)["activeWorkout.settings.matchTier"].waitForExistence(timeout: 10), "Match-tier picker missing")
        let matchTier = app.buttons["activeWorkout.settings.matchTier.match"]
        XCTAssertTrue(matchTier.waitForExistence(timeout: 5), "Match tier option missing")
        matchTier.tap()
        saveScreenshot("AppStore_v21_04_MatchTier")

        launchAuthenticatedApp()
        tapTab("tab.athlete.insights")
        tapSegment("Recovery")
        let detail = app.buttons["recovery.openDetail"]
        if !detail.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(detail.waitForExistence(timeout: 10), "Recovery detail action missing")
        detail.tap()
        XCTAssertTrue(app.descendants(matching: .any)["recoveryDetail.checkIn"].waitForExistence(timeout: 10), "Recovery detail did not open")
        saveScreenshot("AppStore_v21_05_ReadinessSignals")

        launchAuthenticatedApp()
        tapTab("tab.athlete.train")
        let planToday = app.buttons["workoutLog.planToday"]
        if !planToday.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(planToday.waitForExistence(timeout: 10), "Plan Today row missing")
        planToday.tap()
        XCTAssertTrue(app.buttons["planToday.enterLift"].waitForExistence(timeout: 10), "Manual lift entry action missing")
        app.buttons["planToday.enterLift"].tap()
        XCTAssertTrue(app.staticTexts["manualLift.state"].waitForExistence(timeout: 10), "Manual lift plan input missing")
        saveScreenshot("AppStore_v21_06_PlanInput")
    }

    func test02_Workload() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.insights")
        tapSegment("Load")
        sleep(2)
        saveScreenshot("02_Workload")
    }

    func test03_Recovery() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.insights")
        tapSegment("Recovery")
        sleep(2)
        saveScreenshot("03_Recovery")
    }

    func test04_WorkoutLog() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")
        sleep(2)
        saveScreenshot("04_WorkoutLog")
    }

    func test04B_TemplatePickerAndEditorUseStandardSheetActions() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        let startButton = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Workout start button not found")
        startButton.tap()

        XCTAssertTrue(app.staticTexts["workoutStart.state"].waitForExistence(timeout: 10), "Unified workout start state missing")
        XCTAssertTrue(app.buttons["workoutStart.planToday"].waitForExistence(timeout: 5), "Plan Today route missing from unified start")
        XCTAssertTrue(app.buttons["workoutStart.importText"].waitForExistence(timeout: 5), "Text import route missing from unified start")
        XCTAssertTrue(app.buttons["workoutStart.importAI"].waitForExistence(timeout: 5), "AI import route missing from unified start")
        XCTAssertTrue(app.buttons["workoutStart.importHealth"].waitForExistence(timeout: 5), "Health import route missing from unified start")
        XCTAssertTrue(app.buttons["templatePicker.cancel"].waitForExistence(timeout: 10), "Template picker cancel action missing")
        XCTAssertTrue(app.buttons["templatePicker.startBlank"].waitForExistence(timeout: 10), "Template picker primary bottom action missing")
        XCTAssertTrue(app.buttons["templatePicker.createTemplate"].waitForExistence(timeout: 10), "Template picker secondary bottom action missing")
        XCTAssertTrue(app.staticTexts["templatePicker.actionHint"].waitForExistence(timeout: 5), "Template picker action hint missing")

        app.buttons["templatePicker.createTemplate"].tap()

        XCTAssertTrue(app.staticTexts["templateEditor.state"].waitForExistence(timeout: 10), "Template editor state strip missing")
        XCTAssertTrue(app.staticTexts["templateEditor.state"].label.contains("Template name required"), "Template editor did not explain disabled save state")
        let save = app.buttons["templateEditor.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Template editor bottom save action missing")
        XCTAssertFalse(save.isEnabled, "Template editor save should be disabled until a name exists")

        let name = app.textFields["templateEditor.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10), "Template editor name field missing")
        name.tap()
        name.typeText("Standard Template")
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Template editor save disappeared while keyboard was active")
        XCTAssertTrue(save.isEnabled, "Template editor save did not enable after entering a name")
    }

    func test04G_TrainProgramRowStartsTemplateDirectly() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        let programStart = app.buttons.matching(identifier: "workoutLog.programStart").firstMatch
        if !programStart.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(programStart.waitForExistence(timeout: 10), "Train program start row missing")
        XCTAssertTrue(programStart.label.contains("Start"), "Train program row did not expose an explicit Start action")
        programStart.tap()

        XCTAssertTrue(app.textFields["activeWorkout.sessionName"].waitForExistence(timeout: 10), "Program row did not open active workout directly")
    }

    func test04E_WorkoutStartTextImportUsesStandardSheetActions() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        let startButton = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Workout start button not found")
        startButton.tap()

        let importText = app.buttons["workoutStart.importText"]
        XCTAssertTrue(importText.waitForExistence(timeout: 10), "Text import route missing")
        importText.tap()

        XCTAssertTrue(app.staticTexts["workoutImport.state"].waitForExistence(timeout: 10), "Workout import state missing")
        let importButton = app.buttons["workoutImport.importText"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 10), "Workout import bottom action missing")
        XCTAssertFalse(importButton.isEnabled, "Text import should be disabled until text is entered")

        let textView = app.textViews["workoutImport.text"]
        XCTAssertTrue(textView.waitForExistence(timeout: 10), "Workout import text view missing")
        textView.tap()
        textView.typeText("Day 1: Upper Body\nBench Press 4x8 @RPE 7\nBarbell Row 4x8")

        XCTAssertTrue(importButton.waitForExistence(timeout: 5), "Workout import action disappeared after typing")
        XCTAssertTrue(importButton.isEnabled, "Text import did not enable after entering workout text")
        importButton.tap()

        XCTAssertTrue(app.staticTexts["workoutImport.state"].label.contains("Imported"), "Text import did not expose imported state")
        XCTAssertTrue(app.buttons["workoutImport.cancel"].exists, "Workout import cancel action missing")
    }

    func test04F_WorkoutStartAIAndHealthImportsAreExecutableUIKitFlows() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        let startButton = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Workout start button not found")
        startButton.tap()

        let importAI = app.buttons["workoutStart.importAI"]
        XCTAssertTrue(importAI.waitForExistence(timeout: 10), "AI import route missing")
        importAI.tap()

        XCTAssertTrue(app.staticTexts["workoutImport.state"].waitForExistence(timeout: 10), "AI import state missing")
        let aiText = app.textViews["workoutImport.aiText"]
        XCTAssertTrue(aiText.waitForExistence(timeout: 10), "AI import text view missing")
        aiText.tap()
        aiText.typeText("Coach notes: lower body\nBack Squat 5x3 @RPE 8\nRomanian Deadlift 3x8")

        let parseAI = app.buttons["workoutImport.parseAI"]
        XCTAssertTrue(parseAI.waitForExistence(timeout: 5), "AI parse action missing")
        XCTAssertTrue(parseAI.isEnabled, "AI parse did not enable after entering notes")
        parseAI.tap()
        XCTAssertTrue(app.staticTexts["workoutImport.state"].label.contains("Parsed and imported"), "AI import did not execute local parse")
        XCTAssertFalse(app.staticTexts["workoutImport.state"].label.contains("hookup"), "AI import still exposes placeholder hookup copy")

        app.buttons["workoutImport.cancel"].tap()
        let healthRoute = app.buttons["workoutStart.importHealth"]
        XCTAssertTrue(healthRoute.waitForExistence(timeout: 10), "Health import route missing after returning from AI import")
        healthRoute.tap()

        XCTAssertTrue(app.staticTexts["workoutImport.state"].waitForExistence(timeout: 10), "Health import state missing")
        let scanHealth = app.buttons["workoutImport.scanHealth"]
        XCTAssertTrue(scanHealth.waitForExistence(timeout: 10), "Health scan action missing")
        scanHealth.tap()
        XCTAssertTrue(app.staticTexts["workoutImport.state"].waitForExistence(timeout: 10), "Health scan state missing after scan")
        XCTAssertFalse(app.staticTexts["workoutImport.state"].label.contains("hookup"), "Health import still exposes placeholder hookup copy")
    }

    func test04D_TemplateManagerOpensPreviewBeforeEditing() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        let manager = app.buttons["workoutLog.templateManager"]
        if !manager.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(manager.waitForExistence(timeout: 10), "Template manager row missing")
        manager.tap()

        let template = app.buttons.matching(identifier: "templateManager.template").firstMatch
        XCTAssertTrue(template.waitForExistence(timeout: 10), "Managed template row missing")
        template.tap()

        XCTAssertTrue(app.staticTexts["templatePreview.state"].waitForExistence(timeout: 10), "Template preview state missing")
        XCTAssertTrue(app.descendants(matching: .any)["templatePreview.exercise"].waitForExistence(timeout: 5), "Template preview exercise rows missing")
        let edit = app.buttons["templatePreview.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "Template preview edit action missing")
        edit.tap()

        XCTAssertTrue(app.staticTexts["templateEditor.state"].waitForExistence(timeout: 10), "Template editor state missing after preview edit")
        XCTAssertTrue(app.buttons["templateEditor.save"].waitForExistence(timeout: 10), "Template editor save action missing after preview edit")
        XCTAssertTrue(app.buttons["templateEditor.cancel"].exists, "Template editor cancel action missing after preview edit")
    }

    func test04C_ManualLiftPlanUsesStandardSheetActions() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        let planToday = app.buttons["workoutLog.planToday"]
        if !planToday.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(planToday.waitForExistence(timeout: 10), "Plan Today row missing")
        planToday.tap()

        XCTAssertTrue(app.buttons["planToday.enterLift"].waitForExistence(timeout: 10), "Manual lift entry action missing")
        app.buttons["planToday.enterLift"].tap()

        XCTAssertTrue(app.staticTexts["manualLift.state"].waitForExistence(timeout: 10), "Manual lift state strip missing")
        XCTAssertTrue(app.staticTexts["manualLift.state"].label.contains("Lift name required"), "Manual lift missing disabled-state copy")
        let plan = app.buttons["manualLift.plan"]
        XCTAssertTrue(plan.waitForExistence(timeout: 10), "Manual lift bottom plan action missing")
        XCTAssertFalse(plan.isEnabled, "Manual lift plan should be disabled until a lift name exists")

        XCTAssertTrue(app.textFields["manualLift.weight"].waitForExistence(timeout: 5), "Manual lift weight field missing")
        XCTAssertTrue(app.textFields["manualLift.reps"].waitForExistence(timeout: 5), "Manual lift reps field missing")
        let name = app.textFields["manualLift.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "Manual lift name field missing")
        name.tap()
        name.typeText("Back Squat")
        XCTAssertTrue(plan.waitForExistence(timeout: 5), "Manual lift plan action disappeared while keyboard was active")
        XCTAssertTrue(plan.isEnabled, "Manual lift plan did not enable after entering a lift name")
        XCTAssertTrue(app.buttons["manualLift.cancel"].exists, "Manual lift cancel action missing")
    }

    func test05_ActiveWorkout() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")
        let startButton = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Workout start button not found")
        startButton.tap()

        let firstTemplate = app.buttons.matching(identifier: "templatePicker.template").firstMatch
        if firstTemplate.waitForExistence(timeout: 5) {
            firstTemplate.tap()
        } else {
            app.buttons["templatePicker.startBlank"].tap()
        }

        XCTAssertTrue(app.textFields["activeWorkout.sessionName"].waitForExistence(timeout: 10), "Active workout sheet did not open")
        sleep(2)
        saveScreenshot("05_ActiveWorkout")
    }

    func test05B_ActiveWorkoutCancelPromptsWhenEdited() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        let startButton = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Workout start button not found")
        startButton.tap()

        let blankButton = app.buttons["templatePicker.startBlank"]
        XCTAssertTrue(blankButton.waitForExistence(timeout: 10), "Start blank button not found")
        blankButton.tap()

        let sessionName = app.textFields["activeWorkout.sessionName"]
        XCTAssertTrue(sessionName.waitForExistence(timeout: 10), "Active workout sheet did not open")
        sessionName.tap()
        sessionName.typeText("Cancel Guard")

        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Unsaved workout"].waitForExistence(timeout: 10), "Unsaved workout prompt did not appear")
        XCTAssertTrue(app.buttons["Keep Editing"].exists, "Keep Editing action missing")
        XCTAssertTrue(app.buttons["Discard Changes"].exists, "Discard Changes action missing")

        app.buttons["Keep Editing"].tap()
        XCTAssertTrue(sessionName.waitForExistence(timeout: 5), "Workout dismissed after keeping edits")

        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Unsaved workout"].waitForExistence(timeout: 5), "Unsaved workout prompt did not reappear")
        app.buttons["Discard Changes"].tap()
        XCTAssertFalse(app.textFields["activeWorkout.sessionName"].waitForExistence(timeout: 5), "Workout did not dismiss after discard")
    }

    func test05C_ActiveWorkoutDockAndSetStates() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        let startButton = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Workout start button not found")
        startButton.tap()

        let blankButton = app.buttons["templatePicker.startBlank"]
        XCTAssertTrue(blankButton.waitForExistence(timeout: 10), "Start blank button not found")
        blankButton.tap()

        let addExerciseButton = app.buttons["activeWorkout.addExercise"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 10), "Dock add exercise action missing")
        addExerciseButton.tap()

        XCTAssertTrue(app.staticTexts["exercisePicker.state"].waitForExistence(timeout: 10), "Exercise picker state missing")
        XCTAssertTrue(app.buttons["exercisePicker.cancel"].exists, "Exercise picker cancel action missing")
        let firstExercise = app.buttons.matching(identifier: "exercisePicker.exercise").firstMatch
        XCTAssertTrue(firstExercise.waitForExistence(timeout: 10), "Exercise picker row missing")
        firstExercise.tap()

        let firstSetState = app.staticTexts["activeWorkout.setState.0.0"]
        XCTAssertTrue(firstSetState.waitForExistence(timeout: 10), "Set state label missing")
        XCTAssertEqual(firstSetState.label, "Empty")
        let exerciseProgress = app.staticTexts["activeWorkout.exerciseProgress.0"]
        XCTAssertTrue(exerciseProgress.waitForExistence(timeout: 5), "Exercise progress label missing")
        XCTAssertEqual(exerciseProgress.label, "0 / 1 sets")

        let finishButton = app.buttons["activeWorkout.finish"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 5), "Dock finish action missing")
        XCTAssertTrue(finishButton.label.contains("0/1"), "Finish progress did not start at 0/1")

        let markDoneButton = app.buttons["activeWorkout.markDone.0.0"]
        XCTAssertTrue(markDoneButton.waitForExistence(timeout: 5), "Set done action missing")
        markDoneButton.tap()

        XCTAssertTrue(app.staticTexts["activeWorkout.setState.0.0"].label.contains("Completed"), "Set state did not change to Completed")
        XCTAssertTrue(app.buttons["activeWorkout.finish"].label.contains("1/1"), "Finish progress did not update to 1/1")
        XCTAssertEqual(app.staticTexts["activeWorkout.exerciseProgress.0"].label, "1 / 1 sets", "Exercise progress did not update to 1/1")
        XCTAssertTrue(app.staticTexts["activeWorkout.completedSummary.0.0"].waitForExistence(timeout: 5), "Completed summary did not appear")
        XCTAssertTrue(app.buttons["activeWorkout.editSet.0.0"].exists, "Completed set edit action missing")
        XCTAssertFalse(app.textFields["activeWorkout.field.weight.0.0"].exists, "Completed set did not collapse its input fields")

        app.buttons["activeWorkout.editSet.0.0"].tap()
        XCTAssertTrue(app.textFields["activeWorkout.field.weight.0.0"].waitForExistence(timeout: 5), "Completed set did not reopen for editing")

        app.buttons["activeWorkout.skip.0.0"].tap()
        XCTAssertTrue(app.staticTexts["activeWorkout.setState.0.0"].label.contains("Skipped"), "Set state did not change to Skipped")
        XCTAssertTrue(app.staticTexts["activeWorkout.skippedSummary.0.0"].waitForExistence(timeout: 5), "Skipped summary did not appear")
        XCTAssertFalse(app.textFields["activeWorkout.field.weight.0.0"].exists, "Skipped set still showed input fields")
        XCTAssertTrue(app.buttons["activeWorkout.finish"].label.contains("0/1"), "Skipped set still counted as complete")
        XCTAssertEqual(app.staticTexts["activeWorkout.exerciseProgress.0"].label, "0 / 1 sets", "Skipped set still counted in exercise progress")

        app.buttons["activeWorkout.finish"].tap()
        let commitFinish = app.buttons["finishWorkout.commit"]
        XCTAssertTrue(commitFinish.waitForExistence(timeout: 10), "Finish workout confirmation did not open")
        commitFinish.tap()

        XCTAssertTrue(app.staticTexts["No sets marked done"].waitForExistence(timeout: 10), "Zero-completed-set guard did not appear")
        app.buttons["Discard session"].tap()
        XCTAssertFalse(app.textFields["activeWorkout.sessionName"].waitForExistence(timeout: 5), "Discarding zero-completed workout did not dismiss")
    }

    func test05D_ActiveWorkoutSaveFailureKeepsWorkoutOpen() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_SAVE_FAILURE_MODE"], waitForTab: true)
        tapTab("tab.athlete.train")

        let startButton = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Workout start button not found")
        startButton.tap()

        let blankButton = app.buttons["templatePicker.startBlank"]
        XCTAssertTrue(blankButton.waitForExistence(timeout: 10), "Start blank button not found")
        blankButton.tap()

        let addExerciseButton = app.buttons["activeWorkout.addExercise"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 10), "Dock add exercise action missing")
        addExerciseButton.tap()

        let firstExercise = app.buttons.matching(identifier: "exercisePicker.exercise").firstMatch
        XCTAssertTrue(firstExercise.waitForExistence(timeout: 10), "Exercise picker row missing")
        firstExercise.tap()

        let markDoneButton = app.buttons["activeWorkout.markDone.0.0"]
        XCTAssertTrue(markDoneButton.waitForExistence(timeout: 10), "Set done action missing")
        markDoneButton.tap()

        app.buttons["activeWorkout.finish"].tap()
        let commitFinish = app.buttons["finishWorkout.commit"]
        XCTAssertTrue(commitFinish.waitForExistence(timeout: 10), "Finish workout confirmation did not open")
        commitFinish.tap()

        XCTAssertTrue(app.staticTexts["Could not save session"].waitForExistence(timeout: 10), "Save failure alert did not appear")
        app.buttons["OK"].tap()
        XCTAssertTrue(app.textFields["activeWorkout.sessionName"].waitForExistence(timeout: 5), "Workout closed after save failure")
        XCTAssertTrue(app.buttons["activeWorkout.finish"].exists, "Workout dock missing after save failure")
    }

    func test05E_ActiveWorkoutWeightFieldAdvancesToReps() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        let startButton = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Workout start button not found")
        startButton.tap()

        let blankButton = app.buttons["templatePicker.startBlank"]
        XCTAssertTrue(blankButton.waitForExistence(timeout: 10), "Start blank button not found")
        blankButton.tap()

        let addExerciseButton = app.buttons["activeWorkout.addExercise"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 10), "Dock add exercise action missing")
        addExerciseButton.tap()

        let firstExercise = app.buttons.matching(identifier: "exercisePicker.exercise").firstMatch
        XCTAssertTrue(firstExercise.waitForExistence(timeout: 10), "Exercise picker row missing")
        firstExercise.tap()

        let weightField = app.textFields["activeWorkout.field.weight.0.0"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 10), "Weight field missing")
        weightField.tap()
        weightField.typeText("100")

        let nextButton = app.buttons["activeWorkout.keyboard.next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5), "Keyboard Next action missing")
        nextButton.tap()
        app.typeText("5")

        let repsField = app.textFields["activeWorkout.field.reps.0.0"]
        XCTAssertEqual(repsField.value as? String, "5", "Next did not advance focus to reps")
    }

    func test05F_ActiveWorkoutCarryForwardAndRepeatSet() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        let startButton = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Workout start button not found")
        startButton.tap()

        let blankButton = app.buttons["templatePicker.startBlank"]
        XCTAssertTrue(blankButton.waitForExistence(timeout: 10), "Start blank button not found")
        blankButton.tap()

        let addExerciseButton = app.buttons["activeWorkout.addExercise"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 10), "Dock add exercise action missing")
        addExerciseButton.tap()

        let firstExercise = app.buttons.matching(identifier: "exercisePicker.exercise").firstMatch
        XCTAssertTrue(firstExercise.waitForExistence(timeout: 10), "Exercise picker row missing")
        firstExercise.tap()

        let weightField = app.textFields["activeWorkout.field.weight.0.0"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 10), "Weight field missing")
        weightField.tap()
        weightField.typeText("100")

        let nextButton = app.buttons["activeWorkout.keyboard.next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5), "Keyboard Next action missing")
        nextButton.tap()
        app.typeText("5")

        let doneButton = app.buttons["activeWorkout.keyboard.done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5), "Keyboard Done action missing")
        doneButton.tap()

        let addSetButton = app.buttons["activeWorkout.addSet.0"]
        XCTAssertTrue(addSetButton.waitForExistence(timeout: 5), "Add set action missing")
        addSetButton.tap()

        XCTAssertTrue(app.staticTexts["activeWorkout.setState.0.1"].waitForExistence(timeout: 5), "Carried set state missing")
        XCTAssertEqual(app.staticTexts["activeWorkout.setState.0.1"].label, "Planned", "Carried set did not render as planned ghost")
        XCTAssertEqual(app.staticTexts["activeWorkout.exerciseProgress.0"].label, "1 / 2 sets", "Carried set should not count as completed")
        XCTAssertTrue(app.buttons["activeWorkout.finish"].label.contains("1/2"), "Dock progress did not show carried set")

        let repeatButton = app.buttons["activeWorkout.repeatLast.0"]
        XCTAssertTrue(repeatButton.waitForExistence(timeout: 5), "Repeat last action missing")
        repeatButton.tap()

        XCTAssertTrue(app.staticTexts["activeWorkout.setState.0.2"].label.contains("Completed"), "Repeated set did not render as completed")
        XCTAssertTrue(app.staticTexts["activeWorkout.completedSummary.0.2"].waitForExistence(timeout: 5), "Repeated set summary missing")
        XCTAssertEqual(app.staticTexts["activeWorkout.exerciseProgress.0"].label, "2 / 3 sets", "Repeated set did not count as completed")
        XCTAssertTrue(app.buttons["activeWorkout.finish"].label.contains("2/3"), "Dock progress did not include repeated set")
    }

    func test05G_ActiveWorkoutWarmupCountsAsCompletedSet() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        let startButton = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Workout start button not found")
        startButton.tap()

        let blankButton = app.buttons["templatePicker.startBlank"]
        XCTAssertTrue(blankButton.waitForExistence(timeout: 10), "Start blank button not found")
        blankButton.tap()

        let addExerciseButton = app.buttons["activeWorkout.addExercise"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 10), "Dock add exercise action missing")
        addExerciseButton.tap()

        let firstExercise = app.buttons.matching(identifier: "exercisePicker.exercise").firstMatch
        XCTAssertTrue(firstExercise.waitForExistence(timeout: 10), "Exercise picker row missing")
        firstExercise.tap()

        let warmupButton = app.buttons["activeWorkout.warmup.0.0"]
        XCTAssertTrue(warmupButton.waitForExistence(timeout: 10), "Warm-up action missing")
        warmupButton.tap()

        XCTAssertTrue(app.staticTexts["activeWorkout.setState.0.0"].label.contains("Warm-up"), "Warm-up state label missing")
        XCTAssertTrue(app.buttons["activeWorkout.finish"].label.contains("0/1"), "Warm-up alone should not complete the set")

        let markDoneButton = app.buttons["activeWorkout.markDone.0.0"]
        XCTAssertTrue(markDoneButton.waitForExistence(timeout: 5), "Set done action missing")
        markDoneButton.tap()

        let state = app.staticTexts["activeWorkout.setState.0.0"].label
        XCTAssertTrue(state.contains("Completed"), "Warm-up set did not become completed")
        XCTAssertTrue(state.contains("Warm-up"), "Warm-up label was lost after completion")
        XCTAssertTrue(app.buttons["activeWorkout.finish"].label.contains("1/1"), "Completed warm-up did not count in dock progress")
        XCTAssertEqual(app.staticTexts["activeWorkout.exerciseProgress.0"].label, "1 / 1 sets", "Completed warm-up did not count in exercise progress")
    }

    func test05H_ActiveWorkoutSessionSettingsOwnsSportAndType() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        let startButton = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Workout start button not found")
        startButton.tap()

        let blankButton = app.buttons["templatePicker.startBlank"]
        XCTAssertTrue(blankButton.waitForExistence(timeout: 10), "Start blank button not found")
        blankButton.tap()

        let sessionSettings = app.buttons["activeWorkout.sessionSettings"]
        XCTAssertTrue(sessionSettings.waitForExistence(timeout: 10), "Session settings row missing")
        XCTAssertTrue(sessionSettings.label.contains("Lifting"), "Session settings did not expose current sport")
        XCTAssertTrue(sessionSettings.label.contains("Strength"), "Session settings did not expose current type")
        sessionSettings.tap()

        let sportRow = app.buttons["activeWorkout.settings.sport"]
        XCTAssertTrue(sportRow.waitForExistence(timeout: 10), "Sport setting row missing")
        XCTAssertTrue(app.buttons["activeWorkout.settings.type"].exists, "Session type setting row missing")
        XCTAssertTrue(app.staticTexts["activeWorkout.settings.state"].waitForExistence(timeout: 5), "Session settings state missing")
        XCTAssertTrue(app.buttons["activeWorkout.settings.cancel"].exists, "Session settings cancel action missing")

        sportRow.tap()
        let runningChoice = app.buttons["Running"]
        XCTAssertTrue(runningChoice.waitForExistence(timeout: 5), "Running sport choice missing")
        runningChoice.tap()

        XCTAssertTrue(app.staticTexts["Running"].waitForExistence(timeout: 5), "Sport setting did not update to Running")
        XCTAssertTrue(app.staticTexts["Cardio"].waitForExistence(timeout: 5), "Session type did not default to Cardio after choosing Running")

        let done = app.buttons["activeWorkout.settings.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Session settings Done action missing")
        done.tap()

        XCTAssertTrue(app.buttons["activeWorkout.sessionSettings"].waitForExistence(timeout: 5), "Workout did not return after closing settings")
        XCTAssertTrue(app.buttons["activeWorkout.sessionSettings"].label.contains("Running"), "Workout session settings summary did not retain Running")
        XCTAssertTrue(app.buttons["activeWorkout.sessionSettings"].label.contains("Cardio"), "Workout session settings summary did not retain Cardio")
    }

    func test05I_ActiveWorkoutTemplateRIRShowsOnlyRIR() throws {
        startTemplateWorkout(named: "RIR Strength")

        XCTAssertTrue(app.textFields["activeWorkout.field.rir.0.0"].waitForExistence(timeout: 10), "RIR effort field missing")
        XCTAssertFalse(app.textFields["activeWorkout.field.rpe.0.0"].exists, "RPE field should not appear when authored target uses RIR")
        XCTAssertTrue(app.textFields["activeWorkout.field.weight.0.0"].exists, "Weight field missing for strength template")
        XCTAssertTrue(app.textFields["activeWorkout.field.reps.0.0"].exists, "Reps field missing for strength template")
    }

    func test05J_ActiveWorkoutTemplateDistanceDurationFields() throws {
        startTemplateWorkout(named: "Tempo Run")

        XCTAssertTrue(app.textFields["activeWorkout.field.distance.0.0"].waitForExistence(timeout: 10), "Distance field missing for run template")
        XCTAssertTrue(app.textFields["activeWorkout.field.duration.0.0"].exists, "Duration field missing for run template")
        XCTAssertTrue(app.textFields["activeWorkout.field.rpe.0.0"].exists, "RPE field missing for run template")
        XCTAssertFalse(app.textFields["activeWorkout.field.weight.0.0"].exists, "Weight field should not appear for run template")
        XCTAssertFalse(app.textFields["activeWorkout.field.reps.0.0"].exists, "Reps field should not appear for run template")
    }

    func test05K_ActiveWorkoutTemplateRepsOnlyFields() throws {
        startTemplateWorkout(named: "Bodyweight Circuit")

        XCTAssertTrue(app.textFields["activeWorkout.field.reps.0.0"].waitForExistence(timeout: 10), "Reps field missing for bodyweight template")
        XCTAssertTrue(app.textFields["activeWorkout.field.rpe.0.0"].exists, "RPE field missing for bodyweight template")
        XCTAssertFalse(app.textFields["activeWorkout.field.weight.0.0"].exists, "Weight field should not appear for bodyweight template")
        XCTAssertFalse(app.textFields["activeWorkout.field.distance.0.0"].exists, "Distance field should not appear for bodyweight template")
        XCTAssertFalse(app.textFields["activeWorkout.field.duration.0.0"].exists, "Duration field should not appear for bodyweight template")
    }

    func test05L_ActiveWorkoutLargeDynamicTypeKeepsCoreControlsReachable() throws {
        launchApp(
            arguments: [
                "SCREENSHOT_MODE",
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryXXXL"
            ],
            waitForTab: true
        )
        tapTab("tab.athlete.train")

        let startButton = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Workout start button not found")
        startButton.tap()

        let blankButton = app.buttons["templatePicker.startBlank"]
        XCTAssertTrue(blankButton.waitForExistence(timeout: 10), "Start blank button not found at large Dynamic Type")
        blankButton.tap()

        XCTAssertTrue(app.textFields["activeWorkout.sessionName"].waitForExistence(timeout: 10), "Session name missing at large Dynamic Type")
        XCTAssertTrue(app.buttons["activeWorkout.sessionSettings"].exists, "Session settings missing at large Dynamic Type")
        XCTAssertTrue(app.buttons["activeWorkout.addExercise"].exists, "Dock add exercise missing at large Dynamic Type")
        XCTAssertTrue(app.buttons["activeWorkout.finish"].exists, "Dock finish missing at large Dynamic Type")

        app.buttons["activeWorkout.addExercise"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "exercisePicker.exercise").firstMatch.waitForExistence(timeout: 10), "Exercise picker rows missing at large Dynamic Type")
    }

    func test05M_ActiveWorkoutIncrementControlsUpdateWeight() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        let startButton = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Workout start button not found")
        startButton.tap()

        let blankButton = app.buttons["templatePicker.startBlank"]
        XCTAssertTrue(blankButton.waitForExistence(timeout: 10), "Start blank button not found")
        blankButton.tap()

        let addExerciseButton = app.buttons["activeWorkout.addExercise"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 10), "Dock add exercise action missing")
        addExerciseButton.tap()

        let firstExercise = app.buttons.matching(identifier: "exercisePicker.exercise").firstMatch
        XCTAssertTrue(firstExercise.waitForExistence(timeout: 10), "Exercise picker row missing")
        firstExercise.tap()

        let weightField = app.textFields["activeWorkout.field.weight.0.0"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 10), "Weight field missing")
        let increment = app.buttons["activeWorkout.field.weight.0.0.increment"]
        XCTAssertTrue(increment.waitForExistence(timeout: 5), "Weight increment control missing")
        increment.tap()

        XCTAssertEqual(weightField.value as? String, "2.5", "Weight increment did not apply the kg step")
        XCTAssertTrue(app.buttons["activeWorkout.finish"].label.contains("1/1"), "Incremented set did not update completion progress")

        let decrement = app.buttons["activeWorkout.field.weight.0.0.decrement"]
        XCTAssertTrue(decrement.exists, "Weight decrement control missing")
        decrement.tap()
        XCTAssertEqual(weightField.value as? String, "0", "Weight decrement did not apply the kg step")
    }

    func test05N_ActiveWorkoutPostSaveFeedbackIncludesTemplateSave() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        let startButton = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Workout start button not found")
        startButton.tap()

        let blankButton = app.buttons["templatePicker.startBlank"]
        XCTAssertTrue(blankButton.waitForExistence(timeout: 10), "Start blank button not found")
        blankButton.tap()

        let addExerciseButton = app.buttons["activeWorkout.addExercise"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 10), "Dock add exercise action missing")
        addExerciseButton.tap()

        let firstExercise = app.buttons.matching(identifier: "exercisePicker.exercise").firstMatch
        XCTAssertTrue(firstExercise.waitForExistence(timeout: 10), "Exercise picker row missing")
        firstExercise.tap()

        let increment = app.buttons["activeWorkout.field.weight.0.0.increment"]
        XCTAssertTrue(increment.waitForExistence(timeout: 5), "Weight increment control missing")
        increment.tap()

        app.buttons["activeWorkout.finish"].tap()
        XCTAssertTrue(app.staticTexts["finishWorkout.state"].waitForExistence(timeout: 10), "Finish workout state missing")
        XCTAssertTrue(app.sliders["finishWorkout.rpe"].waitForExistence(timeout: 5), "Finish workout RPE slider missing")
        let templateSwitch = app.switches["finishWorkout.saveAsTemplate"]
        XCTAssertTrue(templateSwitch.waitForExistence(timeout: 10), "Save-as-template switch missing")
        templateSwitch.tap()
        XCTAssertTrue(app.textFields["finishWorkout.templateName"].waitForExistence(timeout: 5), "Template name field missing after enabling template save")

        let commitFinish = app.buttons["finishWorkout.commit"]
        XCTAssertTrue(commitFinish.waitForExistence(timeout: 5), "Finish workout confirmation did not open")
        commitFinish.tap()

        XCTAssertTrue(app.staticTexts["Session Saved"].waitForExistence(timeout: 10), "Post-save feedback title missing")
        XCTAssertTrue(app.staticTexts["workoutPostSave.item.saved.title"].exists, "Workout logged feedback missing")
        XCTAssertTrue(app.staticTexts["workoutPostSave.item.template.title"].exists, "Template saved feedback missing")

        let done = app.buttons["workoutPostSave.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Post-save Done action missing")
        done.tap()
        XCTAssertFalse(app.buttons["activeWorkout.finish"].waitForExistence(timeout: 5), "Workout did not dismiss after post-save Done")
    }

    func test05O_ActiveWorkoutResolvedVerdictShowsSuggestedAdjustment() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        let todayPlan = app.buttons["workoutLog.todayPlan"]
        XCTAssertTrue(todayPlan.waitForExistence(timeout: 10), "Today plan row missing")
        XCTAssertTrue(todayPlan.label.contains("Adjusted Squat"), "Screenshot adjusted plan was not surfaced")
        todayPlan.tap()

        XCTAssertTrue(app.textFields["activeWorkout.sessionName"].waitForExistence(timeout: 10), "Resolved active workout did not open")
        XCTAssertTrue(app.staticTexts["activeWorkout.setState.0.0"].waitForExistence(timeout: 5), "Warm-up state label missing")

        let adjustedState = app.staticTexts["activeWorkout.setState.0.1"]
        XCTAssertTrue(adjustedState.waitForExistence(timeout: 10), "Adjusted set state label missing")
        XCTAssertTrue(adjustedState.label.contains("Suggested adjustment"), "Adjusted set did not expose suggested-adjustment state")
        XCTAssertTrue(adjustedState.label.contains("140 kg -> 130 kg"), "Adjusted set did not show planned-to-resolved weight")
        XCTAssertTrue(adjustedState.label.contains("RPE 8 -> 7"), "Adjusted set did not show planned-to-resolved RPE")
    }

    func test05P_ActiveWorkoutPartialCompletionPersistsOnlyDoneSets() throws {
        startTemplateWorkout(named: "RIR Strength")

        let firstWeightIncrement = app.buttons["activeWorkout.field.weight.0.0.increment"]
        XCTAssertTrue(firstWeightIncrement.waitForExistence(timeout: 10), "First planned set weight increment missing")
        firstWeightIncrement.tap()

        app.buttons["activeWorkout.finish"].tap()
        let commitFinish = app.buttons["finishWorkout.commit"]
        XCTAssertTrue(commitFinish.waitForExistence(timeout: 10), "Finish workout confirmation did not open")
        commitFinish.tap()

        let done = app.buttons["workoutPostSave.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "Post-save Done action missing")
        done.tap()

        let history = app.buttons["workoutLog.history"]
        if !history.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(history.waitForExistence(timeout: 10), "Workout history row missing after save")
        history.tap()

        let savedSession = app.buttons
            .matching(identifier: "workoutHistory.session")
            .matching(NSPredicate(format: "label CONTAINS %@", "RIR Strength"))
            .firstMatch
        XCTAssertTrue(savedSession.waitForExistence(timeout: 10), "Saved RIR Strength session not found")
        savedSession.tap()

        let firstSet = app.staticTexts["sessionDetail.set.0.0.detail"]
        XCTAssertTrue(firstSet.waitForExistence(timeout: 10), "Saved first set row missing")
        XCTAssertTrue(firstSet.label.contains("72.5 kg"), "Edited performed weight was not persisted")
        XCTAssertFalse(firstSet.label.contains("5 reps"), "Ghost target reps were persisted as performed reps")
        XCTAssertFalse(firstSet.label.contains("RIR 2"), "Ghost target RIR was persisted as performed effort")
        XCTAssertFalse(app.staticTexts["sessionDetail.set.0.1.detail"].exists, "Unfinished planned set was persisted")
    }

    // MARK: - PDF Export Screenshot (6)

    func test06_PDFExport() throws {
        launchAuthenticatedApp()
        // Navigate to Insights > Load where PDF export is accessible via toolbar.
        tapTab("tab.athlete.insights")
        tapSegment("Load")
        sleep(2)

        // Tap the export button in the navigation bar toolbar
        let exportButton = app.buttons["export.workoutData"]
        if exportButton.waitForExistence(timeout: 3) {
            exportButton.tap()
            sleep(1)

            // Tap the PDF report button in the confirmation dialog (stable id, locale-independent)
            let pdfButton = app.buttons["export.pdfReport"]
            if pdfButton.waitForExistence(timeout: 3) {
                pdfButton.tap()
                sleep(2)
                saveScreenshot("06_PDFExport")
            } else {
                // Fallback: capture the export dialog itself
                saveScreenshot("06_PDFExport")
            }
        } else {
            // Fallback: capture the Load view as PDF export context
            saveScreenshot("06_PDFExport")
        }
    }

    func test06B_PDFExportKeepsPrimaryActionStableWhileGenerating() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_PDF_GENERATING_MODE"], waitForTab: true)
        tapTab("tab.athlete.insights")
        tapSegment("Load")

        let exportButton = app.buttons["export.workoutData"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 10), "Export action missing")
        exportButton.tap()

        XCTAssertTrue(app.staticTexts["export.options.state"].waitForExistence(timeout: 10), "Export options state missing")
        XCTAssertTrue(app.buttons["export.csvSummary"].waitForExistence(timeout: 5), "Session summary CSV action missing")
        XCTAssertTrue(app.buttons["export.csvDetailed"].waitForExistence(timeout: 5), "Detailed sets CSV action missing")
        let pdfButton = app.buttons["export.pdfReport"]
        XCTAssertTrue(pdfButton.waitForExistence(timeout: 10), "PDF report action missing")
        pdfButton.tap()

        XCTAssertTrue(app.staticTexts["export.pdf.state"].waitForExistence(timeout: 10), "PDF report state missing")
        XCTAssertTrue(app.staticTexts["export.pdf.state"].label.contains("Generating report"), "PDF generating state missing")
        let generate = app.buttons["export.pdf.generate"]
        XCTAssertTrue(generate.waitForExistence(timeout: 5), "Generate action disappeared while loading")
        XCTAssertFalse(generate.isEnabled, "Generate action should be disabled while loading")
        XCTAssertTrue(app.buttons["export.pdf.range.28"].waitForExistence(timeout: 5), "Default PDF range missing")
        XCTAssertTrue(app.buttons["export.pdf.cancel"].exists, "PDF cancel action missing")
    }

    func test07_InsightsReselectReturnsOverview() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.insights")
        tapSegment("Load")
        XCTAssertTrue(app.buttons["export.workoutData"].waitForExistence(timeout: 10), "Load section did not appear")

        tapTab("tab.athlete.insights")
        XCTAssertTrue(app.staticTexts["CROSS-SIGNAL READ"].waitForExistence(timeout: 10), "Insights reselect did not return to Overview")
    }

    func test07B_InsightsSectionPreservesLoadScroll() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.insights")
        tapSegment("Load")

        let exportButton = app.buttons["export.workoutData"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 10), "Load section did not appear")
        app.swipeUp()
        XCTAssertTrue(exportButton.isHittable, "Load section did not scroll to the export row")

        tapSegment("Recovery")
        XCTAssertTrue(app.staticTexts["RECOVERY"].waitForExistence(timeout: 10), "Recovery section did not appear")

        tapSegment("Load")
        XCTAssertTrue(exportButton.waitForExistence(timeout: 10), "Load section did not restore")
        XCTAssertTrue(exportButton.isHittable, "Load section did not preserve its scroll position")
    }

    func test07C_InsightsOverviewShowsStructuredCrossSignalRows() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.insights")

        XCTAssertTrue(app.staticTexts["CROSS-SIGNAL READ"].waitForExistence(timeout: 10), "Insights overview did not appear")
        XCTAssertTrue(app.staticTexts["insights.overview.insight.recovery.title"].waitForExistence(timeout: 10), "Recovery insight row missing")
        XCTAssertTrue(app.staticTexts["insights.overview.insight.recovery.changed"].exists, "Recovery insight missing what-changed copy")
        XCTAssertTrue(app.staticTexts["insights.overview.insight.recovery.why"].exists, "Recovery insight missing why-it-matters copy")
        XCTAssertTrue(app.staticTexts["insights.overview.insight.recovery.next"].exists, "Recovery insight missing watch-next copy")

        XCTAssertTrue(app.staticTexts["insights.overview.insight.load.title"].waitForExistence(timeout: 5), "Load insight row missing")
        XCTAssertTrue(app.staticTexts["insights.overview.insight.relationship.title"].waitForExistence(timeout: 5), "Relationship insight row missing")

        tapSegment("Load")
        XCTAssertTrue(app.buttons["export.workoutData"].waitForExistence(timeout: 10), "Load section did not appear")
        tapTab("tab.athlete.insights")
        XCTAssertTrue(app.staticTexts["insights.overview.insight.relationship.title"].waitForExistence(timeout: 10), "Overview did not restore structured insight rows")
    }

    func test07D_InsightsOverviewRowsOpenDetailSections() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.insights")

        let recoveryDetail = app.buttons["insights.overview.recoveryDetail"]
        if !recoveryDetail.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(recoveryDetail.waitForExistence(timeout: 10), "Recovery detail overview row missing")
        recoveryDetail.tap()
        XCTAssertTrue(app.staticTexts["RECOVERY"].waitForExistence(timeout: 10), "Recovery detail row did not open Recovery section")

        tapTab("tab.athlete.insights")
        let loadDetail = app.buttons["insights.overview.loadDetail"]
        if !loadDetail.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(loadDetail.waitForExistence(timeout: 10), "Load detail overview row missing")
        loadDetail.tap()
        XCTAssertTrue(app.buttons["export.workoutData"].waitForExistence(timeout: 10), "Load detail row did not open Load section")
    }

    func test07E_RecoveryMorningCheckInUsesStandardSheetActions() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.insights")
        tapSegment("Recovery")

        let checkIn = app.buttons["recovery.morningCheckIn"]
        if !checkIn.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(checkIn.waitForExistence(timeout: 10), "Morning check-in action missing")
        checkIn.tap()

        XCTAssertTrue(app.staticTexts["morningCheckIn.state"].waitForExistence(timeout: 10), "Morning check-in state missing")
        XCTAssertTrue(app.buttons["morningCheckIn.save"].waitForExistence(timeout: 10), "Morning check-in bottom save action missing")
        XCTAssertTrue(app.buttons["morningCheckIn.cancel"].exists, "Morning check-in cancel action missing")
        XCTAssertTrue(app.buttons["morningCheckIn.sleep.3"].waitForExistence(timeout: 5), "Sleep score control missing")
        XCTAssertTrue(app.buttons["morningCheckIn.energy.5"].waitForExistence(timeout: 5), "Energy score control missing")

        app.buttons["morningCheckIn.energy.5"].tap()
        XCTAssertTrue(app.staticTexts["morningCheckIn.energy.state"].label.contains("5/5"), "Energy score state did not update")
        app.buttons["morningCheckIn.save"].tap()

        let detail = app.buttons["recovery.openDetail"]
        if !detail.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(detail.waitForExistence(timeout: 10), "Recovery detail action missing after saving check-in")
        detail.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["recoveryDetail.checkIn"].waitForExistence(timeout: 10),
            "Saved morning check-in did not appear in recovery detail"
        )
    }

    func test08_Login() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_AUTH_MODE"], waitForTab: false)
        XCTAssertTrue(app.textFields["auth.email"].waitForExistence(timeout: 10), "Login email field not found")
        sleep(1)
        saveScreenshot("08_Login")
    }

    func test08B_AuthCommunicatesInvalidLoadingOfflineAndSocialStates() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_AUTH_MODE", "SCREENSHOT_AUTH_INVALID_MODE"], waitForTab: false)
        XCTAssertTrue(app.staticTexts["auth.state"].waitForExistence(timeout: 10), "Auth state label missing")
        XCTAssertTrue(app.staticTexts["auth.state"].label.contains("Invalid"), "Invalid auth state missing")
        XCTAssertTrue(app.staticTexts["auth.email.error"].waitForExistence(timeout: 5), "Email invalid state missing")
        XCTAssertTrue(app.staticTexts["auth.password.error"].waitForExistence(timeout: 5), "Password invalid state missing")

        app.terminate()
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_AUTH_MODE", "SCREENSHOT_AUTH_LOADING_MODE"], waitForTab: false)
        XCTAssertTrue(app.staticTexts["auth.state"].waitForExistence(timeout: 10), "Credential loading state label missing")
        XCTAssertTrue(app.staticTexts["auth.state"].label.contains("Signing in"), "Credential loading state missing")
        XCTAssertTrue(app.buttons["auth.signIn"].waitForExistence(timeout: 5), "Sign-in action missing in loading state")

        app.terminate()
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_AUTH_MODE", "SCREENSHOT_AUTH_SOCIAL_LOADING_MODE"], waitForTab: false)
        XCTAssertTrue(app.staticTexts["auth.state"].waitForExistence(timeout: 10), "Social loading state label missing")
        XCTAssertTrue(app.staticTexts["auth.state"].label.contains("Google sign-in loading"), "Social loading state missing")
        XCTAssertTrue(app.buttons["auth.google"].waitForExistence(timeout: 5), "Google auth action missing")

        app.terminate()
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_AUTH_MODE", "SCREENSHOT_AUTH_OFFLINE_MODE"], waitForTab: false)
        XCTAssertTrue(app.staticTexts["auth.state"].waitForExistence(timeout: 10), "Offline state label missing")
        XCTAssertTrue(app.staticTexts["auth.state"].label.contains("Offline"), "Offline auth state missing")
        XCTAssertTrue(app.staticTexts["auth.error"].waitForExistence(timeout: 5), "Offline auth error missing")
    }

    func test08C_AuthSignUpSportUsesStandardChoiceSheet() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_AUTH_MODE"], waitForTab: false)

        let switchMode = app.buttons["auth.switchMode"]
        XCTAssertTrue(switchMode.waitForExistence(timeout: 10), "Auth mode switch missing")
        switchMode.tap()

        let sport = app.buttons["auth.primarySport"]
        XCTAssertTrue(sport.waitForExistence(timeout: 10), "Primary sport row missing in sign-up mode")
        sport.tap()

        XCTAssertTrue(app.staticTexts["choice.state"].waitForExistence(timeout: 10), "Sport choice state missing")
        let running = app.buttons["Running"]
        XCTAssertTrue(running.waitForExistence(timeout: 5), "Running sport choice missing")
        running.tap()

        XCTAssertTrue(app.buttons["auth.primarySport"].waitForExistence(timeout: 5), "Primary sport row did not return after choice")
        XCTAssertTrue(app.buttons["auth.primarySport"].label.contains("Running"), "Primary sport did not update after choice")
    }

    func test09_Onboarding() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_ONBOARDING_MODE"], waitForTab: false)
        let onboardingRoot = app.otherElements["onboarding.flow"]
        let onboardingTitle = app.staticTexts["Choose your language"]
        XCTAssertTrue(
            onboardingRoot.waitForExistence(timeout: 10) || onboardingTitle.waitForExistence(timeout: 3),
            "Onboarding flow not found"
        )
        sleep(1)
        saveScreenshot("09_Onboarding")
    }

    func test09B_OnboardingCommunicatesProgressSelectionHealthAndSummary() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_ONBOARDING_MODE"], waitForTab: false)

        XCTAssertTrue(app.staticTexts["onboarding.progress"].waitForExistence(timeout: 10), "Onboarding progress text missing")
        XCTAssertTrue(app.staticTexts["onboarding.progress"].label.contains("Step 1 of 5"), "Onboarding progress did not use understandable step text")
        XCTAssertTrue(app.buttons["onboarding.option.language.en"].waitForExistence(timeout: 10), "Language option missing")
        XCTAssertTrue(app.buttons["onboarding.option.language.en"].label.contains("Selected"), "Selected language did not expose selected state")

        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.progress"].label.contains("Step 2 of 5"), "Frequency step progress missing")
        let frequency = app.buttons["onboarding.option.frequency.threeToFour"]
        XCTAssertTrue(frequency.waitForExistence(timeout: 10), "Training frequency option missing")
        frequency.tap()
        XCTAssertTrue(app.buttons["onboarding.option.frequency.threeToFour"].label.contains("Selected"), "Selected frequency did not expose selected state")

        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.progress"].label.contains("Step 3 of 5"), "Experience step progress missing")
        let experience = app.buttons["onboarding.option.experience.intermediate"]
        XCTAssertTrue(experience.waitForExistence(timeout: 10), "Experience option missing")
        experience.tap()

        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.progress"].label.contains("Step 4 of 5"), "Health step progress missing")
        XCTAssertTrue(app.staticTexts["onboarding.health.privacy"].waitForExistence(timeout: 10), "Health privacy copy missing")
        XCTAssertTrue(app.buttons["onboarding.health.connect"].exists, "Health connect action missing")
        XCTAssertTrue(app.buttons["onboarding.health.skip"].exists, "Health skip action missing")
        app.buttons["onboarding.health.skip"].tap()

        XCTAssertTrue(app.staticTexts["onboarding.progress"].label.contains("Step 5 of 5"), "Ready step progress missing")
        XCTAssertTrue(app.staticTexts["onboarding.summary.confirmation"].waitForExistence(timeout: 10), "Ready summary confirmation missing")
        XCTAssertTrue(app.otherElements["onboarding.summary.frequency"].waitForExistence(timeout: 5), "Frequency summary missing")
        XCTAssertTrue(app.otherElements["onboarding.summary.experience"].waitForExistence(timeout: 5), "Experience summary missing")
        XCTAssertTrue(app.otherElements["onboarding.summary.health"].waitForExistence(timeout: 5), "Health summary missing")
        XCTAssertTrue(app.buttons["onboarding.ready.complete"].exists, "Ready completion action missing")
    }

    func test10_CoachRoster() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_COACH_MODE"], waitForTab: true)
        XCTAssertTrue(app.tabBars.buttons["tab.coach.roster"].waitForExistence(timeout: 10), "Coach roster tab not found")
        XCTAssertFalse(app.tabBars.buttons["tab.athlete.today"].exists, "Athlete tabs should not be visible in coach shell")
        XCTAssertTrue(app.staticTexts["ROSTER"].waitForExistence(timeout: 10), "Coach roster hero not found")
        let athlete = app.buttons
            .matching(identifier: "coachRoster.athlete")
            .matching(NSPredicate(format: "label CONTAINS %@", "Jordan Lee"))
            .firstMatch
        XCTAssertTrue(athlete.waitForExistence(timeout: 10), "Seeded coach athlete not found")
        XCTAssertTrue(athlete.label.contains("Today:"), "Coach roster row missing today status")
        XCTAssertTrue(athlete.label.contains("Last session:"), "Coach roster row missing last-session status")
        XCTAssertTrue(athlete.label.contains("Attention:"), "Coach roster row missing attention status")
        XCTAssertTrue(athlete.label.contains("Pending plan:"), "Coach roster row missing pending-plan status")
        sleep(1)
        saveScreenshot("10_CoachRoster")
    }

    func test10B_CoachRosterOpensAthleteDetailSections() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_COACH_MODE"], waitForTab: true)
        let athlete = app.buttons
            .matching(identifier: "coachRoster.athlete")
            .matching(NSPredicate(format: "label CONTAINS %@", "Jordan Lee"))
            .firstMatch
        XCTAssertTrue(athlete.waitForExistence(timeout: 10), "Seeded coach athlete not found")
        athlete.tap()

        XCTAssertTrue(app.staticTexts["coachAthleteDetail.overview"].waitForExistence(timeout: 10), "Coach athlete overview section missing")
        tapSegment("Plan")
        XCTAssertTrue(app.staticTexts["coachAthleteDetail.plan"].waitForExistence(timeout: 10), "Coach athlete plan section missing")
        XCTAssertTrue(app.staticTexts["coachAthleteDetail.plan.lifecycle"].exists, "Coach athlete plan lifecycle copy missing")
        tapSegment("History")
        XCTAssertTrue(app.staticTexts["coachAthleteDetail.history"].waitForExistence(timeout: 10), "Coach athlete history section missing")
    }

    func test10G_CoachAndAthleteContextsPreserveNavigationStacks() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_COACH_MODE"], waitForTab: true)
        let athlete = app.buttons
            .matching(identifier: "coachRoster.athlete")
            .matching(NSPredicate(format: "label CONTAINS %@", "Jordan Lee"))
            .firstMatch
        XCTAssertTrue(athlete.waitForExistence(timeout: 10), "Seeded coach athlete not found")
        athlete.tap()
        XCTAssertTrue(app.staticTexts["coachAthleteDetail.overview"].waitForExistence(timeout: 10), "Coach detail stack did not open")

        tapTab("tab.coach.profile")
        let returnToAthlete = app.buttons["coachProfile.returnToAthlete"]
        XCTAssertTrue(returnToAthlete.waitForExistence(timeout: 10), "Return to athlete context action missing")
        returnToAthlete.tap()

        XCTAssertTrue(
            waitForTab("tab.athlete.today", timeout: 20),
            "Athlete shell did not appear after context switch\n\(app.debugDescription)"
        )
        tapTab("tab.athlete.profile")
        let coachMode = app.buttons["profile.coachMode"]
        XCTAssertTrue(coachMode.waitForExistence(timeout: 10), "Coach mode row missing after returning to athlete shell")
        coachMode.tap()

        XCTAssertTrue(waitForTab("tab.coach.roster", timeout: 10), "Coach shell did not restore")
        tapTab("tab.coach.roster")
        XCTAssertTrue(app.staticTexts["coachAthleteDetail.overview"].waitForExistence(timeout: 10), "Coach roster navigation stack was not preserved across context switch")
    }

    func test10C_CoachPrescriptionFlowUsesStandardSheetActions() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_COACH_MODE"], waitForTab: true)
        let athlete = app.buttons
            .matching(identifier: "coachRoster.athlete")
            .matching(NSPredicate(format: "label CONTAINS %@", "Jordan Lee"))
            .firstMatch
        XCTAssertTrue(athlete.waitForExistence(timeout: 10), "Seeded coach athlete not found")
        athlete.tap()

        tapSegment("Plan")
        let prescribe = app.buttons["coachAthleteDetail.prescribe"]
        XCTAssertTrue(prescribe.waitForExistence(timeout: 10), "Coach prescribe action missing")
        prescribe.tap()

        XCTAssertTrue(app.staticTexts["coachPrescription.state"].waitForExistence(timeout: 10), "Coach prescription state missing")
        XCTAssertTrue(app.buttons["coachPrescription.assign"].waitForExistence(timeout: 10), "Coach prescription bottom assign action missing")
        XCTAssertTrue(app.buttons["coachPrescription.cancel"].exists, "Coach prescription cancel action missing")
        let template = app.buttons.matching(identifier: "coachPrescription.template").firstMatch
        XCTAssertTrue(template.waitForExistence(timeout: 10), "Coach prescription template choice missing")
        XCTAssertTrue(template.label.contains("Selected"), "Default coach prescription template did not expose selected state")
        XCTAssertTrue(app.buttons["coachPrescription.schedule.today"].waitForExistence(timeout: 5), "Today schedule choice missing")
        XCTAssertTrue(app.buttons["coachPrescription.schedule.tomorrow"].waitForExistence(timeout: 5), "Tomorrow schedule choice missing")
        XCTAssertTrue(app.textFields["coachPrescription.notes"].waitForExistence(timeout: 5), "Coach prescription notes field missing")

        app.buttons["coachPrescription.schedule.tomorrow"].tap()
        XCTAssertTrue(app.buttons["coachPrescription.schedule.tomorrow"].label.contains("Selected"), "Schedule selection did not update")
        app.buttons["coachPrescription.assign"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["coachAthleteDetail.plan.prescription"].waitForExistence(timeout: 10),
            "Assigned coach prescription did not appear in athlete plan list"
        )
    }

    func test10E_CoachPlansRootOwnsTemplateAndAssignmentActions() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_COACH_MODE"], waitForTab: true)
        tapTab("tab.coach.plans")

        XCTAssertTrue(app.staticTexts["coachPlans.state"].waitForExistence(timeout: 10), "Coach Plans state missing")
        XCTAssertTrue(app.buttons["coachPlans.newTemplate"].waitForExistence(timeout: 10), "Coach Plans new-template action missing")
        XCTAssertTrue(app.buttons["coachPlans.assignPlan"].waitForExistence(timeout: 10), "Coach Plans assign action missing")

        let template = app.buttons.matching(identifier: "coachPlans.template").firstMatch
        XCTAssertTrue(template.waitForExistence(timeout: 10), "Coach Plans template row missing")
        template.tap()
        XCTAssertTrue(app.staticTexts["templatePreview.state"].waitForExistence(timeout: 10), "Coach Plans template did not open preview")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["coachPlans.state"].waitForExistence(timeout: 10), "Coach Plans root did not restore after preview")

        app.buttons["coachPlans.assignPlan"].tap()
        XCTAssertTrue(app.staticTexts["coachPlanAssignment.state"].waitForExistence(timeout: 10), "Coach plan assignment state missing")
        let athlete = app.buttons.matching(identifier: "coachPlanAssignment.athlete").firstMatch
        XCTAssertTrue(athlete.waitForExistence(timeout: 10), "Coach plan assignment athlete row missing")
        athlete.tap()

        XCTAssertTrue(app.staticTexts["coachPrescription.state"].waitForExistence(timeout: 10), "Coach plan assignment did not open prescription")
        XCTAssertTrue(app.buttons["coachPrescription.assign"].waitForExistence(timeout: 10), "Coach prescription assign action missing from Plans flow")
    }

    func test10F_CoachReportsOpenRosterReadout() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_COACH_MODE"], waitForTab: true)
        tapTab("tab.coach.reports")

        XCTAssertTrue(app.staticTexts["coachReports.state"].waitForExistence(timeout: 10), "Coach Reports state missing")
        let rosterReport = app.buttons["coachReports.rosterReport"]
        XCTAssertTrue(rosterReport.waitForExistence(timeout: 10), "Roster report action missing")
        rosterReport.tap()

        XCTAssertTrue(app.staticTexts["coachRosterReport.state"].waitForExistence(timeout: 10), "Roster report state missing")
        let athlete = app.descendants(matching: .any)["coachRosterReport.athlete"]
        XCTAssertTrue(athlete.waitForExistence(timeout: 10), "Roster report athlete row missing")
        XCTAssertTrue(athlete.label.contains("Jordan Lee"), "Roster report did not include seeded athlete")
    }

    func test10D_CoachInviteFlowUsesStandardSheetActions() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_COACH_MODE"], waitForTab: true)
        tapTab("tab.coach.profile")

        let invite = app.buttons["coachProfile.inviteAthlete"]
        XCTAssertTrue(invite.waitForExistence(timeout: 10), "Coach invite destination missing")
        invite.tap()

        XCTAssertTrue(app.staticTexts["invite.state"].waitForExistence(timeout: 10), "Coach invite state missing")
        let send = app.buttons["invite.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 10), "Coach invite send action missing")
        XCTAssertFalse(send.isEnabled, "Coach invite send should be disabled before a valid email")
        let email = app.textFields["invite.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5), "Coach invite email field missing")
        email.tap()
        email.typeText("athlete@example.com")
        XCTAssertTrue(send.waitForExistence(timeout: 5), "Coach invite send disappeared after entering email")
        XCTAssertTrue(send.isEnabled, "Coach invite send did not enable after valid email")
        send.tap()

        XCTAssertTrue(app.staticTexts["invite.state"].label.contains("Invite sent"), "Coach invite did not expose sent state")
        XCTAssertFalse(app.buttons["invite.send"].isEnabled, "Coach invite send should disable after sending")
    }

    func test11_CoachPaywall() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_COACH_PAYWALL_MODE"], waitForTab: true)
        tapTab("tab.athlete.profile")

        let coachMode = app.buttons["profile.coachMode"]
        XCTAssertTrue(coachMode.waitForExistence(timeout: 10), "Coach mode row not found")
        coachMode.tap()

        XCTAssertTrue(app.staticTexts["Coach athletes with clarity"].waitForExistence(timeout: 10), "Coach paywall headline not found")
        XCTAssertTrue(app.staticTexts["COACH TOOLS"].waitForExistence(timeout: 3), "Coach paywall trigger label not found")
        sleep(1)
        saveScreenshot("11_CoachPaywall")
    }

    func test11C_PaywallCommunicatesTierPricingRestoreAndRecoveryStates() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_COACH_PAYWALL_MODE"], waitForTab: true)
        tapTab("tab.athlete.profile")

        let coachMode = app.buttons["profile.coachMode"]
        XCTAssertTrue(coachMode.waitForExistence(timeout: 10), "Coach mode row not found")
        coachMode.tap()

        XCTAssertTrue(app.staticTexts["upgrade.state"].waitForExistence(timeout: 10), "Paywall state label missing")
        XCTAssertTrue(app.otherElements["upgrade.tier.selected"].waitForExistence(timeout: 10), "Selected tier row missing")
        XCTAssertTrue(app.otherElements["upgrade.tier.athletePro"].waitForExistence(timeout: 5), "Athlete Pro distinction missing")
        XCTAssertTrue(app.otherElements["upgrade.tier.coach"].waitForExistence(timeout: 5), "Coach tier distinction missing")
        XCTAssertTrue(app.buttons["upgrade.plan.annual"].waitForExistence(timeout: 5), "Annual plan option missing")
        XCTAssertTrue(app.buttons["upgrade.plan.monthly"].waitForExistence(timeout: 5), "Monthly plan option missing")

        if !app.otherElements["upgrade.disclosure.price"].waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(app.otherElements["upgrade.disclosure.price"].waitForExistence(timeout: 5), "Price disclosure missing")
        XCTAssertTrue(app.otherElements["upgrade.disclosure.trial"].waitForExistence(timeout: 5), "Trial disclosure missing")
        XCTAssertTrue(app.otherElements["upgrade.disclosure.renewal"].waitForExistence(timeout: 5), "Renewal disclosure missing")
        XCTAssertTrue(app.otherElements["upgrade.disclosure.restore"].waitForExistence(timeout: 5), "Restore disclosure missing")
        XCTAssertTrue(app.buttons["upgrade.restore"].waitForExistence(timeout: 5), "Restore action missing")
        XCTAssertTrue(app.buttons["upgrade.cancel"].exists, "Cancel action missing")

        let hasRecoverableFailure = app.buttons["upgrade.retry"].waitForExistence(timeout: 2)
        let hasSubscribe = app.buttons["upgrade.subscribe"].waitForExistence(timeout: 2)
        XCTAssertTrue(hasRecoverableFailure || hasSubscribe, "Paywall missing either retry or subscribe recovery path")
    }

    func test11B_ProfileAccountIsolatesDestructiveActions() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.profile")

        let account = app.buttons["profile.account"]
        if !account.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(account.waitForExistence(timeout: 10), "Account destination missing from Profile hub")
        XCTAssertFalse(app.buttons["profile.account.delete"].exists, "Delete account action should not live on Profile root")
        account.tap()

        XCTAssertTrue(app.buttons["profile.account.signOut"].waitForExistence(timeout: 10), "Account screen sign-out action missing")
        let delete = app.buttons["profile.account.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 10), "Account screen delete action missing")
        delete.tap()

        XCTAssertTrue(app.alerts["Delete Account"].waitForExistence(timeout: 10), "Delete confirmation alert missing")
        app.alerts["Delete Account"].buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["profile.account.delete"].waitForExistence(timeout: 5), "Account screen disappeared after cancelling delete")
    }

    func test11D_ProfileSecondaryFlowsUseStandardSheetActions() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.profile")

        func openProfileRow(_ identifier: String) {
            let row = app.buttons[identifier]
            if !row.waitForExistence(timeout: 3) {
                app.swipeUp()
            }
            XCTAssertTrue(row.waitForExistence(timeout: 10), "Profile row \(identifier) not found")
            row.tap()
        }

        openProfileRow("profile.healthPermissions")
        XCTAssertTrue(app.staticTexts["healthPermissions.state"].waitForExistence(timeout: 10), "Health permission state missing")
        let hasHealthConnect = app.buttons["healthPermissions.connect"].waitForExistence(timeout: 2)
        let hasHealthSettings = app.buttons["healthPermissions.openSettings"].waitForExistence(timeout: 2)
        XCTAssertTrue(hasHealthConnect || hasHealthSettings, "Health permission primary action missing")
        XCTAssertTrue(
            app.descendants(matching: .any)["healthPermissions.data.hrv"].waitForExistence(timeout: 5),
            "Health data scope row missing"
        )
        app.buttons["healthPermissions.cancel"].tap()

        openProfileRow("profile.syncStatus")
        XCTAssertTrue(app.staticTexts["syncStatus.state"].waitForExistence(timeout: 10), "Sync state missing")
        XCTAssertTrue(app.buttons["syncStatus.syncNow"].waitForExistence(timeout: 10), "Sync primary action missing")
        XCTAssertTrue(
            app.descendants(matching: .any)["syncStatus.entity.workouts"].waitForExistence(timeout: 5),
            "Sync entity row missing"
        )
        app.buttons["syncStatus.cancel"].tap()

        openProfileRow("profile.language")
        XCTAssertTrue(app.staticTexts["language.state"].waitForExistence(timeout: 10), "Language state missing")
        XCTAssertTrue(app.buttons["language.done"].waitForExistence(timeout: 10), "Language done action missing")
        let english = app.buttons["language.option.en"]
        let simplifiedChinese = app.buttons["language.option.zh-Hans"]
        XCTAssertTrue(english.waitForExistence(timeout: 5), "English option missing")
        XCTAssertTrue(simplifiedChinese.waitForExistence(timeout: 5), "Simplified Chinese option missing")
        XCTAssertTrue(
            english.label.contains("Selected") || simplifiedChinese.label.contains("Selected"),
            "Active language option did not expose selected state"
        )
    }

    func test11E_TrainingProfileUsesStandardSheetActions() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.profile")

        let trainingProfile = app.buttons["profile.trainingProfile"]
        XCTAssertTrue(trainingProfile.waitForExistence(timeout: 10), "Training profile destination missing")
        trainingProfile.tap()

        XCTAssertTrue(app.staticTexts["trainingProfile.state"].waitForExistence(timeout: 10), "Training profile state missing")
        let save = app.buttons["trainingProfile.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Training profile bottom save action missing")
        XCTAssertTrue(app.buttons["trainingProfile.cancel"].exists, "Training profile cancel action missing")

        let sessionsPerWeek = app.buttons["trainingProfile.sessionsPerWeek"]
        XCTAssertTrue(sessionsPerWeek.waitForExistence(timeout: 10), "Sessions per week row missing")
        sessionsPerWeek.tap()
        XCTAssertTrue(app.buttons["4"].waitForExistence(timeout: 10), "Sessions per week choice missing")
        app.buttons["4"].tap()

        let averageDuration = app.buttons["trainingProfile.averageDuration"]
        XCTAssertTrue(averageDuration.waitForExistence(timeout: 10), "Average duration row missing")
        averageDuration.tap()
        XCTAssertTrue(app.buttons["60 min"].waitForExistence(timeout: 10), "Average duration choice missing")
        app.buttons["60 min"].tap()

        let typicalEffort = app.buttons["trainingProfile.typicalEffort"]
        XCTAssertTrue(typicalEffort.waitForExistence(timeout: 10), "Typical effort row missing")
        typicalEffort.tap()
        XCTAssertTrue(app.buttons["7 -- Hard"].waitForExistence(timeout: 10), "Typical effort choice missing")
        app.buttons["7 -- Hard"].tap()

        let weeksAtLevel = app.buttons["trainingProfile.weeksAtLevel"]
        XCTAssertTrue(weeksAtLevel.waitForExistence(timeout: 10), "Weeks at level row missing")
        weeksAtLevel.tap()
        XCTAssertTrue(app.buttons["4 weeks"].waitForExistence(timeout: 10), "Weeks at level choice missing")
        app.buttons["4 weeks"].tap()

        XCTAssertTrue(app.staticTexts["trainingProfile.state"].label.contains("Ready"), "Training profile state did not become ready")
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Training profile save disappeared")
        XCTAssertTrue(save.isEnabled, "Training profile save did not enable after required fields")
        save.tap()

        XCTAssertTrue(app.buttons["profile.trainingProfile"].waitForExistence(timeout: 10), "Training profile did not dismiss after save")
    }

    func test11F_AthleteInviteCodeFlowUsesStandardSheetActions() throws {
        launchAuthenticatedApp()
        tapTab("tab.athlete.profile")

        let invite = app.buttons["profile.inviteCoach"]
        XCTAssertTrue(invite.waitForExistence(timeout: 10), "Athlete invite destination missing")
        invite.tap()

        XCTAssertTrue(app.staticTexts["invite.state"].waitForExistence(timeout: 10), "Athlete invite state missing")
        let generate = app.buttons["invite.generate"]
        XCTAssertTrue(generate.waitForExistence(timeout: 10), "Athlete invite generate action missing")
        XCTAssertTrue(generate.isEnabled, "Athlete invite generate should be enabled")
        generate.tap()

        XCTAssertTrue(app.descendants(matching: .any)["invite.code"].waitForExistence(timeout: 10), "Generated invite code missing")
        XCTAssertTrue(app.buttons["invite.copyCode"].waitForExistence(timeout: 5), "Invite copy action missing")
        XCTAssertTrue(app.staticTexts["invite.state"].label.contains("Code ready"), "Athlete invite did not expose ready code state")
        XCTAssertTrue(app.buttons["invite.cancel"].exists, "Invite cancel action missing")
    }

    func test12_ChineseShellLocalization() throws {
        launchApp(
            arguments: ["SCREENSHOT_MODE", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_Hans"],
            waitForTab: true
        )

        XCTAssertTrue(app.tabBars.buttons["今日"].waitForExistence(timeout: 10), "Chinese Today tab label not found")
        XCTAssertTrue(app.tabBars.buttons["训练"].waitForExistence(timeout: 3), "Chinese Train tab label not found")
        tapTab("tab.athlete.insights")
        tapSegment("负荷")
        XCTAssertTrue(app.buttons["export.workoutData"].waitForExistence(timeout: 10), "Localized Load section did not appear")

        saveScreenshot("12_ChineseShell")
    }

    // MARK: - Helpers

    private func launchAuthenticatedApp() {
        launchApp(arguments: ["SCREENSHOT_MODE"], waitForTab: true)
    }

    private func launchApp(arguments: [String], waitForTab: Bool) {
        if app.state != .notRunning {
            app.terminate()
        }
        app.launchArguments = arguments
        app.launch()

        guard waitForTab else { return }
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "App failed to load -- tab bar not found")
    }

    private func startTemplateWorkout(named templateName: String) {
        launchAuthenticatedApp()
        tapTab("tab.athlete.train")

        let startButton = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10), "Workout start button not found")
        startButton.tap()

        let templatePredicate = NSPredicate(format: "label CONTAINS %@", templateName)
        let templateButton = app.buttons
            .matching(identifier: "templatePicker.template")
            .matching(templatePredicate)
            .firstMatch
        XCTAssertTrue(templateButton.waitForExistence(timeout: 10), "\(templateName) template not found")
        templateButton.tap()

        XCTAssertTrue(app.textFields["activeWorkout.sessionName"].waitForExistence(timeout: 10), "Active workout did not open from template")
    }

    /// Tap a tab bar button by its stable accessibility identifier (locale-independent).
    /// Waits for the button to exist first to avoid taps racing the app launch.
    private func tapTab(_ identifier: String) {
        let button = app.tabBars.buttons[identifier]
        if button.waitForExistence(timeout: 10) {
            button.tap()
            return
        }

        for label in fallbackTabLabels[identifier, default: []] {
            let fallback = app.tabBars.buttons[label]
            if fallback.waitForExistence(timeout: 3) {
                fallback.tap()
                return
            }
        }

        XCTFail("Tab '\(identifier)' not found by identifier or visible label")
    }

    private func waitForTab(_ identifier: String, timeout: TimeInterval) -> Bool {
        if app.tabBars.buttons[identifier].waitForExistence(timeout: timeout) {
            return true
        }

        for label in fallbackTabLabels[identifier, default: []] {
            if app.tabBars.buttons[label].waitForExistence(timeout: 2) {
                return true
            }
        }

        return false
    }

    private func tapSegment(_ label: String) {
        let button = app.buttons[label]
        if button.waitForExistence(timeout: 10) {
            button.tap()
            return
        }

        XCTFail("Segment '\(label)' not found")
    }

    private func tapLocalizedButton(labels: [String]) {
        for label in labels {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 3) {
                button.tap()
                return
            }
        }

        XCTFail("None of localized buttons found: \(labels.joined(separator: ", "))")
    }

    private var fallbackTabLabels: [String: [String]] {
        [
            "tab.athlete.today": ["Today", "Home", "首页"],
            "tab.athlete.train": ["Train", "训练", "Log", "日志"],
            "tab.athlete.insights": ["Insights", "洞察", "Recovery", "Load", "恢复", "负荷"],
            "tab.athlete.profile": ["Profile", "档案"],
            "tab.coach.roster": ["Roster", "队员"],
            "tab.coach.plans": ["Plans", "计划"],
            "tab.coach.reports": ["Reports", "报告"],
            "tab.coach.profile": ["Profile", "Coach", "档案"]
        ]
    }

    private func saveScreenshot(_ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
