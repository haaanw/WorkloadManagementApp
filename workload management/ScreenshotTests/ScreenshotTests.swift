import XCTest

/// Automated App Store screenshot capture.
///
/// Setup (one-time in Xcode):
/// 1. File → New → Target → UI Testing Bundle → name it "ScreenshotTests"
/// 2. Add this file to the new target
/// 3. Run: Product → Test (or Cmd+U) on iPhone 17 Pro Max simulator
///
/// Screenshots are saved as XCTAttachments in the xcresult bundle.
/// Extract with: `xcrun xcresulttool` or the `xcparse` CLI:
///   brew install chargepoint/xcparse/xcparse
///   xcparse screenshots /tmp/ScreenshotTests.xcresult ~/Desktop/AppStoreScreenshots
///
final class ScreenshotTests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["SCREENSHOT_MODE"]
        app.launch()

        // Wait for app to finish loading
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "App failed to load — tab bar not found")
    }

    // MARK: - Screenshots

    func test01_Dashboard() throws {
        // Dashboard is the first tab, should already be visible
        app.tabBars.buttons["Home"].tap()
        sleep(2)
        saveScreenshot("01_Dashboard")
    }

    func test02_WorkoutLog() throws {
        app.tabBars.buttons["Log"].tap()
        sleep(2)
        saveScreenshot("02_WorkoutLog")
    }

    func test03_ActiveWorkout() throws {
        app.tabBars.buttons["Log"].tap()
        sleep(1)

        // Tap the + button to open active workout sheet
        let addButton = app.navigationBars.buttons.matching(identifier: "plus").firstMatch
        if addButton.waitForExistence(timeout: 3) {
            addButton.tap()
        } else {
            // Fallback: find any + button in the nav bar
            app.navigationBars.buttons.element(boundBy: app.navigationBars.buttons.count - 1).tap()
        }
        sleep(2)
        saveScreenshot("03_ActiveWorkout")

        // Dismiss the sheet
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists { cancelButton.tap() }
    }

    func test04_Recovery() throws {
        app.tabBars.buttons["Recovery"].tap()
        sleep(2)
        saveScreenshot("04_Recovery")
    }

    func test05_WorkloadACWR() throws {
        app.tabBars.buttons["Load"].tap()
        sleep(2)
        saveScreenshot("05_Workload")
    }

    func test06_Profile() throws {
        app.tabBars.buttons["Profile"].tap()
        sleep(2)
        saveScreenshot("06_Profile")
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
