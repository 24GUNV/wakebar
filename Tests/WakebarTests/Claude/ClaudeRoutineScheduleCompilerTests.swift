import XCTest
@testable import WakebarCore

final class ClaudeRoutineScheduleCompilerTests: XCTestCase {
    func testProducesOneRoutineForEachRecurringSessionSlot() throws {
        var schedule = WakeSchedule.default
        schedule.repeatEveryFiveHours = true
        schedule.repeatUntilHour = 19
        schedule.followsSystemTimeZone = false
        schedule.timeZoneIdentifier = "Asia/Bangkok"

        let plans = try ClaudeRoutineScheduleCompiler().plans(for: schedule)

        XCTAssertEqual(plans.count, 3)
        XCTAssertEqual(plans.map(\.hour), [6, 11, 16])
        XCTAssertTrue(plans.allSatisfy { $0.savedPrompt.contains("exactly \"yes\"") })
        XCTAssertTrue(plans.allSatisfy { $0.timeZoneIdentifier == "Asia/Bangkok" })
    }
}
