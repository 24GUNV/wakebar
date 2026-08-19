import XCTest

final class WakebarPhoneLaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFirstLaunchShowsWaitingForSchedule() {
        let app = XCUIApplication()
        app.launchArguments.append("-wakebar-ui-testing")
        app.launch()

        XCTAssertTrue(app.navigationBars["Wakebar"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Waiting for Wakebar"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts[
                "Open Wakebar on your Mac to publish a schedule through iCloud."
            ].exists
        )
    }
}
