import XCTest
@testable import WakebarCore

final class ScheduleMenuPresentationTests: XCTestCase {
    func testPresentationMatrix() {
        let cases: [ScheduleMenuPresentationTestCase] = [
            ScheduleMenuPresentationTestCase(
                name: "disabled draft",
                isEnabled: false,
                providersReady: false,
                alarmEnabled: true,
                phonePhase: .draft,
                state: .draft,
                status: "Draft",
                action: "Set Up Wake Schedule…",
                destination: .schedule
            ),
            ScheduleMenuPresentationTestCase(
                name: "provider setup required",
                isEnabled: true,
                providersReady: false,
                alarmEnabled: true,
                phonePhase: .confirmed,
                state: .actionRequired,
                status: "Setup required",
                action: "Finish Setup…",
                destination: .providers
            ),
            ScheduleMenuPresentationTestCase(
                name: "alarm off",
                isEnabled: true,
                providersReady: true,
                alarmEnabled: false,
                phonePhase: .draft,
                state: .ready,
                status: "Ready",
                action: "Edit Schedule…",
                destination: .schedule
            ),
            ScheduleMenuPresentationTestCase(
                name: "alarm draft",
                isEnabled: true,
                providersReady: true,
                alarmEnabled: true,
                phonePhase: .draft,
                state: .actionRequired,
                status: "Setup required",
                action: "Finish Setup…",
                destination: .alarm
            ),
            ScheduleMenuPresentationTestCase(
                name: "publishing",
                isEnabled: true,
                providersReady: true,
                alarmEnabled: true,
                phonePhase: .publishing,
                state: .inProgress,
                status: "Syncing…",
                action: "View Alarm Status…",
                destination: .alarm
            ),
            ScheduleMenuPresentationTestCase(
                name: "waiting for iPhone",
                isEnabled: true,
                providersReady: true,
                alarmEnabled: true,
                phonePhase: .published,
                state: .inProgress,
                status: "Waiting for iPhone",
                action: "View Alarm Status…",
                destination: .alarm
            ),
            ScheduleMenuPresentationTestCase(
                name: "confirmed",
                isEnabled: true,
                providersReady: true,
                alarmEnabled: true,
                phonePhase: .confirmed,
                state: .ready,
                status: "Ready",
                action: "Edit Schedule…",
                destination: .schedule
            ),
            ScheduleMenuPresentationTestCase(
                name: "failed",
                isEnabled: true,
                providersReady: true,
                alarmEnabled: true,
                phonePhase: .failed,
                state: .actionRequired,
                status: "Needs attention",
                action: "Fix Alarm Sync…",
                destination: .alarm
            ),
        ]

        for testCase in cases {
            let presentation = ScheduleMenuPresentation.resolve(
                isEnabled: testCase.isEnabled,
                providersReady: testCase.providersReady,
                alarmEnabled: testCase.alarmEnabled,
                phonePhase: testCase.phonePhase
            )

            XCTAssertEqual(presentation.state, testCase.state, testCase.name)
            XCTAssertEqual(presentation.statusText, testCase.status, testCase.name)
            XCTAssertEqual(presentation.primaryActionTitle, testCase.action, testCase.name)
            XCTAssertEqual(presentation.destination, testCase.destination, testCase.name)
        }
    }

    func testPhoneStatusMatrix() {
        let cases: [(PhoneAlarmMenuPhase, String, ServiceStatusKind)] = [
            (.draft, "Setup required", .actionRequired),
            (.publishing, "Syncing…", .inProgress),
            (.published, "Waiting for iPhone", .inProgress),
            (.confirmed, "Alarm confirmed", .ready),
            (.failed, "Needs attention", .actionRequired),
        ]

        for (phase, status, kind) in cases {
            let presentation = ScheduleMenuPresentation.resolve(
                isEnabled: true,
                providersReady: true,
                alarmEnabled: true,
                phonePhase: phase
            )

            XCTAssertEqual(presentation.phoneStatusText, status)
            XCTAssertEqual(presentation.phoneStatusKind, kind)
        }
    }
}
