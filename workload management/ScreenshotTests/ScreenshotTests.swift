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
        app.launchArguments = ["SCREENSHOT_MODE"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "App failed to load -- tab bar not found")
    }

    // MARK: - Self-Coached Athlete Screenshots

    func test01_Dashboard() throws {
        sleep(2)
        saveScreenshot("01_Dashboard")
    }

    func test02_Workload() throws {
        tapTab("tab.load")
        sleep(2)
        saveScreenshot("02_Workload")
    }

    func test03_Recovery() throws {
        tapTab("tab.recovery")
        sleep(2)
        saveScreenshot("03_Recovery")
    }

    func test04_WorkoutLog() throws {
        tapTab("tab.log")
        sleep(2)
        saveScreenshot("04_WorkoutLog")
    }

    func test05_ActiveWorkout() throws {
        tapTab("tab.log")
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

    // MARK: - PDF Export Screenshot (6)

    func test06_PDFExport() throws {
        // Navigate to Load tab where PDF export is accessible via toolbar
        tapTab("tab.load")
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

    // MARK: - Helpers

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

    private var fallbackTabLabels: [String: [String]] {
        [
            "tab.home": ["Home", "首页"],
            "tab.log": ["Log", "日志"],
            "tab.recovery": ["Recovery", "恢复"],
            "tab.load": ["Load", "负荷"],
            "tab.profile": ["Profile", "档案"]
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
