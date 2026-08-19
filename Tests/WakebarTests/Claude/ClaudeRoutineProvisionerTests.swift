import Foundation
import XCTest
@testable import WakebarCore

final class ClaudeRoutineProvisionerTests: XCTestCase {
    func testPlanExplainsCloudAndUserManagedBoundaries() throws {
        let request = ClaudeRoutineScheduleRequest(
            name: "Wake Claude before work",
            hour: 6,
            minute: 50,
            weekdays: .workweek,
            timeZoneIdentifier: "Asia/Bangkok"
        )

        let plan = try ClaudeRoutineProvisioner().makePlan(for: request)

        XCTAssertTrue(plan.capability.runsWhenMacIsOff)
        XCTAssertEqual(plan.capability.provisioningControl, .userManaged)
        XCTAssertEqual(plan.managementURL.host, "claude.ai")
        XCTAssertTrue(plan.savedPrompt.contains("Reply with exactly \"yes\""))
        XCTAssertTrue(plan.savedPrompt.contains("Do not inspect repositories"))
        XCTAssertTrue(plan.limitations.contains { $0.contains("cannot create or edit") })
    }

    func testPlanRejectsInvalidSchedule() {
        let request = ClaudeRoutineScheduleRequest(
            name: "Wake Claude",
            hour: 24,
            minute: 0,
            weekdays: .workweek,
            timeZoneIdentifier: "UTC"
        )

        XCTAssertThrowsError(
            try ClaudeRoutineProvisioner().makePlan(for: request)
        ) { error in
            XCTAssertEqual(error as? ClaudeRoutineProvisioningError, .invalidTime)
        }
    }
}
