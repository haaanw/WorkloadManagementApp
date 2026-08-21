import XCTest

/// Automated App Store screenshot capture + navigation/content smoke for the LIVE SwiftUI
/// surface (v1.6 "Ink & Grain" — Stage 4b rewrite).
///
/// History: the previous 49-test suite asserted the retired UIKit shell's identifiers
/// (tab.athlete.*, workoutStart.*, activeWorkout.settings.*, coach surfaces) and failed by
/// design after the Stage R rehost (36747b8). This suite targets the SwiftUI tree via the
/// stable IDs added in Stages R/4a/4b: app.loading(.view), tabbar.ink, tab.*,
/// dashboard.hero, workoutLog.verdictCard/.reason/.strikeZone, workoutLog.startWorkout,
/// templatePicker.startBlank, activeWorkout.addExercise, recovery.scoreCard, workload.acwr,
/// export.workoutData, profile.movementBank. Coach-mode tests were deleted (coach UI is
/// intentionally absent from the rehosted app), not ported.
///
/// Run on two simulators for both required App Store device sizes (ASO-03):
///   - 6.7" (iPhone 15 Pro Max class)
///   - 6.5" (iPhone 11 Pro Max class)
///
/// Extract screenshots from the xcresult bundle:
///   xcparse screenshots <path-to>.xcresult ~/Desktop/AppStoreScreenshots
///
final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    /// Swallows issues raised while a launch attempt is being retried (v1.7.2 codebase audit).
    /// Set only for the duration of a non-final attempt in `launchWithRetry`.
    private var isRetryingLaunch = false

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func record(_ issue: XCTIssue) {
        guard !isRetryingLaunch else { return }
        super.record(issue)
    }

    // MARK: - Launch helpers

    private func launchApp(arguments: [String], waitForTabBar: Bool = true) {
        app.launchArguments = arguments
        // Localized capture: pass TEST_RUNNER_SCREENSHOT_LANG=zh-Hans to xcodebuild to shoot
        // the zh-Hans App Store set (xcodebuild forwards TEST_RUNNER_-prefixed vars here).
        if let lang = ProcessInfo.processInfo.environment["SCREENSHOT_LANG"], !lang.isEmpty {
            app.launchArguments += ["-AppleLanguages", "(\(lang))"]
            if lang == "zh-Hans" {
                app.launchArguments += ["-AppleLocale", "zh_CN"]
            }
        }
        launchWithRetry()
        if waitForTabBar {
            XCTAssertTrue(
                app.otherElements["tabbar.ink"].waitForExistence(timeout: 15),
                "InkTabBar did not appear — SCREENSHOT_MODE bootstrap failed"
            )
        }
    }

    /// Launches the app, retrying a simulator boot flake.
    ///
    /// Seen three times across the 1.7.1 UAT rounds, always the same shape:
    /// `FBSOpenApplicationServiceErrorDomain Code=1 … RequestDenied` from SpringBoard, on the
    /// first launch after a cold simulator boot, passing on the very next run with no code
    /// change. That is infrastructure, not a product defect, but it fails the whole suite and
    /// costs a full re-run to distinguish from a real regression.
    ///
    /// A retry needs two things. `launch()` reports a boot failure as an XCTIssue rather than
    /// a thrown error, so `continueAfterFailure` must be on for the attempt to be survivable,
    /// and the issue itself is swallowed by `record(_:)` — but ONLY on a non-final attempt, so
    /// a genuinely unlaunchable app still fails loudly with its original diagnostics. The
    /// terminate between attempts clears a half-launched process, which is the state that
    /// makes an immediate retry fail for the same reason as the first try.
    private func launchWithRetry(attempts: Int = 3) {
        let previousContinueAfterFailure = continueAfterFailure
        defer {
            continueAfterFailure = previousContinueAfterFailure
            isRetryingLaunch = false
        }

        for attempt in 1...attempts {
            let isFinalAttempt = attempt == attempts
            isRetryingLaunch = !isFinalAttempt
            continueAfterFailure = !isFinalAttempt || previousContinueAfterFailure

            app.launch()
            if app.wait(for: .runningForeground, timeout: 30) { return }

            guard !isFinalAttempt else { break }
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 10)
            Thread.sleep(forTimeInterval: 2)
        }

        XCTFail("The app did not reach the foreground after \(attempts) launch attempts")
    }

    private func launchAuthenticatedApp() {
        launchApp(arguments: ["SCREENSHOT_MODE"])
    }

    /// Taps an InkTabBar item by its stable identifier (tab.home / tab.log / tab.recovery /
    /// tab.load / tab.profile).
    private func tapTab(_ identifier: String) {
        let item = app.buttons[identifier]
        XCTAssertTrue(item.waitForExistence(timeout: 10), "Tab item \(identifier) missing")
        item.tap()
    }

    private func saveScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// SwiftUI stamps a container's accessibilityIdentifier onto its descendant ELEMENTS
    /// (StaticText/Button/…), so type-scoped queries like `otherElements[id]` miss.
    /// Query across all element types and take the first match.
    private func anyElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    // MARK: - Launch surface

    func test00_LoadingSurface() throws {
        launchApp(arguments: ["SCREENSHOT_MODE", "SCREENSHOT_LOADING_MODE"], waitForTabBar: false)
        // The container ID propagates onto the loading screen's child elements (see anyElement).
        XCTAssertTrue(anyElement("app.loading.view").waitForExistence(timeout: 10), "Loading surface missing")
        XCTAssertTrue(app.staticTexts["app.loading.view"].firstMatch.waitForExistence(timeout: 5), "Loading state label missing")
    }

    // MARK: - Tab navigation smoke (InkTabBar)

    func test01_TabBar_NavigatesAllFiveTabs() throws {
        launchAuthenticatedApp()
        XCTAssertTrue(anyElement("dashboard.hero").waitForExistence(timeout: 10), "Dashboard hero missing on launch")

        tapTab("tab.log")
        XCTAssertTrue(app.buttons["workoutLog.startWorkout"].waitForExistence(timeout: 10), "Log tab content missing")

        tapTab("tab.recovery")
        XCTAssertTrue(anyElement("recovery.scoreCard").waitForExistence(timeout: 10), "Recovery score card missing")

        tapTab("tab.load")
        XCTAssertTrue(anyElement("workload.acwr").waitForExistence(timeout: 10), "ACWR card missing")

        tapTab("tab.profile")
        XCTAssertTrue(app.buttons["profile.movementBank"].waitForExistence(timeout: 10), "Profile movement-bank row missing")

        tapTab("tab.home")
        XCTAssertTrue(anyElement("dashboard.hero").waitForExistence(timeout: 10), "Dashboard hero missing on return")
    }

    // MARK: - App Store screenshots (primary tabs)

    func test02_Dashboard() throws {
        launchAuthenticatedApp()
        XCTAssertTrue(anyElement("dashboard.hero").waitForExistence(timeout: 10), "Dashboard hero missing")
        sleep(2)
        saveScreenshot("01_Dashboard")
    }

    func test03_WorkoutLog() throws {
        launchAuthenticatedApp()
        tapTab("tab.log")
        XCTAssertTrue(app.buttons["workoutLog.startWorkout"].waitForExistence(timeout: 10), "Workout start action missing")
        sleep(2)
        saveScreenshot("04_WorkoutLog")
    }

    func test04_Workload() throws {
        launchAuthenticatedApp()
        tapTab("tab.load")
        XCTAssertTrue(anyElement("workload.acwr").waitForExistence(timeout: 10), "ACWR card missing")
        sleep(2)
        saveScreenshot("02_Workload")
    }

    func test05_Recovery() throws {
        launchAuthenticatedApp()
        tapTab("tab.recovery")
        XCTAssertTrue(anyElement("recovery.scoreCard").waitForExistence(timeout: 10), "Recovery score card missing")
        sleep(2)
        saveScreenshot("03_Recovery")
    }

    func test06_Profile() throws {
        launchAuthenticatedApp()
        tapTab("tab.profile")
        XCTAssertTrue(app.buttons["profile.movementBank"].waitForExistence(timeout: 10), "Movement-bank row missing")
        sleep(2)
        saveScreenshot("05_Profile")
    }

    // MARK: - Verdict card (the v2.1 App Store hero shots)

    func test07_VerdictCard() throws {
        launchAuthenticatedApp()
        tapTab("tab.log")

        XCTAssertTrue(anyElement("workoutLog.verdict.reason").waitForExistence(timeout: 10), "Verdict reason line missing")
        XCTAssertTrue(anyElement("workoutLog.verdict.strikeZone").waitForExistence(timeout: 5), "Strike-zone bar missing")
        saveScreenshot("AppStore_v21_01_VerdictMicrodose")
        saveScreenshot("AppStore_v21_02_StrikeZone")
    }

    // MARK: - Logging flow smoke (start → template picker → active workout → exercise picker)

    func test08_StartWorkout_OpensActiveWorkout() throws {
        launchAuthenticatedApp()
        tapTab("tab.log")

        let start = app.buttons["workoutLog.startWorkout"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "Workout start action missing")
        start.tap()

        let startBlank = app.buttons["templatePicker.startBlank"]
        XCTAssertTrue(startBlank.waitForExistence(timeout: 10), "Template picker blank-start action missing")
        saveScreenshot("06_SessionStart")
        startBlank.tap()

        XCTAssertTrue(app.buttons["activeWorkout.addExercise"].waitForExistence(timeout: 10), "Active workout add-exercise action missing")
        saveScreenshot("07_ActiveWorkout")
    }

    func test09_ExercisePicker_SearchesCatalog() throws {
        launchAuthenticatedApp()
        tapTab("tab.log")
        app.buttons["workoutLog.startWorkout"].tap()
        let startBlank = app.buttons["templatePicker.startBlank"]
        XCTAssertTrue(startBlank.waitForExistence(timeout: 10), "Template picker blank-start action missing")
        startBlank.tap()

        let addExercise = app.buttons["activeWorkout.addExercise"]
        XCTAssertTrue(addExercise.waitForExistence(timeout: 10), "Add-exercise action missing")
        addExercise.tap()

        // Movement-bank catalog picker: search-first surface (.searchable).
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10), "Exercise picker search field missing")
        search.tap()
        search.typeText("squat")
        sleep(1)
        saveScreenshot("08_ExercisePicker")
    }

    // MARK: - Movement bank (Profile → exercise library)

    func test10_MovementBank_Opens() throws {
        launchAuthenticatedApp()
        tapTab("tab.profile")

        let row = app.buttons["profile.movementBank"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Movement-bank row missing")
        row.tap()

        // MovementBankView: pushed screen. The "New Exercise" toolbar action carries the
        // locale-stable SF-symbol identifier "plus"; the .searchable field stays collapsed
        // until a pull-down, so it is revealed best-effort rather than asserted.
        XCTAssertTrue(app.buttons["plus"].waitForExistence(timeout: 10), "Movement bank did not open")
        app.swipeDown()
        _ = app.searchFields.firstMatch.waitForExistence(timeout: 3)
        sleep(1)
        saveScreenshot("09_MovementBank")
    }

    // MARK: - Export surface

    func test11_Export_ActionsPresent() throws {
        launchAuthenticatedApp()
        tapTab("tab.load")
        XCTAssertTrue(app.buttons["export.workoutData"].waitForExistence(timeout: 10), "Workout-data export action missing")
    }

    // MARK: - Template picker content

    func test12_TemplatePicker_ShowsTemplates() throws {
        launchAuthenticatedApp()
        tapTab("tab.log")
        app.buttons["workoutLog.startWorkout"].tap()

        XCTAssertTrue(app.buttons["templatePicker.startBlank"].waitForExistence(timeout: 10), "Template picker missing")
        // Seeded data includes at least one template row in SCREENSHOT_MODE; tolerate zero
        // rather than assert seed internals, but capture the surface either way.
        _ = app.descendants(matching: .any)["templatePicker.template"].waitForExistence(timeout: 3)
        saveScreenshot("10_TemplatePicker")
    }
}
