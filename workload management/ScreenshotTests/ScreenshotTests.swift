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

    // MARK: - Athlete Mode Screenshots (1-4, 6)

    func test01_Dashboard() throws {
        app.tabBars.buttons["Home"].tap()
        sleep(2)
        saveScreenshot("01_Dashboard")
    }

    func test02_Workload() throws {
        app.tabBars.buttons["Load"].tap()
        sleep(2)
        saveScreenshot("02_Workload")
    }

    func test03_Recovery() throws {
        app.tabBars.buttons["Recovery"].tap()
        sleep(2)
        saveScreenshot("03_Recovery")
    }

    func test04_WorkoutLog() throws {
        app.tabBars.buttons["Log"].tap()
        sleep(2)
        saveScreenshot("04_WorkoutLog")
    }

    // MARK: - Coach Mode Screenshot (5)

    func test05_CoachRoster() throws {
        // Coach roster requires relaunching in coach mode.
        // Plan 01 added COACH_MODE launch argument handling to AppRouter:
        //   - Sets container.setMode(.coach)
        //   - Overrides subscription with isCoach: true
        app.terminate()
        app.launchArguments = ["SCREENSHOT_MODE", "COACH_MODE"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Coach mode failed to load")

        // Coach mode shows "Roster" tab
        let rosterTab = app.tabBars.buttons["Roster"]
        if rosterTab.waitForExistence(timeout: 5) {
            rosterTab.tap()
        }
        sleep(2)
        saveScreenshot("05_CoachRoster")

        // Restore athlete mode for next test
        app.terminate()
        app.launchArguments = ["SCREENSHOT_MODE"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    }

    // MARK: - PDF Export Screenshot (6)

    func test06_PDFExport() throws {
        // Navigate to Load tab where PDF export is accessible via toolbar
        app.tabBars.buttons["Load"].tap()
        sleep(2)

        // Tap the export button in the navigation bar toolbar
        let exportButton = app.buttons["Export workout data"]
        if exportButton.waitForExistence(timeout: 3) {
            exportButton.tap()
            sleep(1)

            // Tap "PDF Report (Pro)" in the confirmation dialog
            let pdfButton = app.buttons["PDF Report (Pro)"]
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

    private func saveScreenshot(_ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
