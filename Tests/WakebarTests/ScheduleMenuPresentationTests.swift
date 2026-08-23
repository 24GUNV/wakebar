import XCTest
@testable import WakebarCore

final class ScheduleMenuPresentationTests: XCTestCase {
    func testDisabledSavedScheduleCanBeEdited() {
        let presentation = ScheduleMenuPresentation.resolve(
            isEnabled: false,
            hasSchedule: true,
            providersReady: true
        )

        XCTAssertEqual(presentation.state, .draft)
        XCTAssertEqual(presentation.statusText, "Off")
        XCTAssertEqual(presentation.primaryActionTitle, "Edit Schedule…")
        XCTAssertEqual(presentation.destination, .schedule)
    }

    func testActiveScheduleNeedsProviderSetup() {
        let presentation = ScheduleMenuPresentation.resolve(
            isEnabled: true,
            providersReady: false
        )

        XCTAssertEqual(presentation.state, .actionRequired)
        XCTAssertEqual(presentation.primaryActionTitle, "Finish Setup…")
        XCTAssertEqual(presentation.destination, .providers)
    }

    func testActiveConfiguredScheduleIsReady() {
        let presentation = ScheduleMenuPresentation.resolve(
            isEnabled: true,
            providersReady: true
        )

        XCTAssertEqual(presentation.state, .ready)
        XCTAssertEqual(presentation.statusText, "Ready")
        XCTAssertEqual(presentation.destination, .schedule)
    }
}
