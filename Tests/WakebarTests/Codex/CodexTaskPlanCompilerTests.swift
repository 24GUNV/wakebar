import Foundation
import XCTest
@testable import WakebarCore

final class CodexTaskPlanCompilerTests: XCTestCase {
    func testCompilesWeekdayWakeInSelectedTimeZone() {
        var schedule = WakeSchedule.default
        schedule.isEnabled = true
        schedule.followsSystemTimeZone = false
        schedule.timeZoneIdentifier = "Asia/Bangkok"

        let plan = CodexTaskPlanCompiler().compile(schedule: schedule)

        XCTAssertEqual(plan, [
            CodexTaskSpec(
                name: "\(CodexTaskPlanCompiler.namePrefix(for: schedule)) Morning",
                schedule: "RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;BYHOUR=6;BYMINUTE=50;BYSECOND=0",
                timeZoneIdentifier: "Asia/Bangkok",
                prompt: "hi",
                enabled: true,
                weekdays: Weekday.workweek,
                hour: 6,
                minute: 50
            ),
        ])
    }

    func testIgnoresFiveHourRefreshCadence() {
        var schedule = WakeSchedule.default
        schedule.isEnabled = true
        schedule.repeatEveryFiveHours = true
        schedule.repeatUntilHour = 19
        schedule.followsSystemTimeZone = false
        schedule.timeZoneIdentifier = "America/New_York"

        let plan = CodexTaskPlanCompiler().compile(schedule: schedule)

        XCTAssertEqual(plan.map(\.schedule), [
            "RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR;BYHOUR=6;BYMINUTE=50;BYSECOND=0",
        ])
        XCTAssertEqual(plan.map(\.name), [
            "\(CodexTaskPlanCompiler.namePrefix(for: schedule)) Morning",
        ])
        XCTAssertTrue(plan.allSatisfy { $0.timeZoneIdentifier == "America/New_York" })
    }

    func testLeadTimeMovesSundayWakeToSaturday() {
        var schedule = WakeSchedule.default
        schedule.isEnabled = true
        schedule.hour = 0
        schedule.minute = 5
        schedule.sessionLeadMinutes = 10
        schedule.selectedWeekdays = [.sunday]

        let plan = CodexTaskPlanCompiler().compile(schedule: schedule)

        XCTAssertEqual(
            plan.map(\.schedule),
            ["RRULE:FREQ=WEEKLY;BYDAY=SA;BYHOUR=23;BYMINUTE=55;BYSECOND=0"]
        )
    }

    func testRemovingCodexProducesEmptyPlan() {
        var schedule = WakeSchedule.default
        schedule.includeCodex = false

        XCTAssertTrue(CodexTaskPlanCompiler().compile(schedule: schedule).isEmpty)
    }

    func testNextFireComesFromCompiledLocalSlot() throws {
        var schedule = WakeSchedule.default
        schedule.isEnabled = true
        schedule.followsSystemTimeZone = false
        schedule.timeZoneIdentifier = "Asia/Bangkok"
        schedule.selectedWeekdays = [.monday]
        let reference = try XCTUnwrap(
            Date("2026-08-23T00:00:00Z", strategy: .iso8601)
        )

        let nextFire = CodexTaskPlanCompiler().nextFire(after: reference, schedule: schedule)

        XCTAssertEqual(
            nextFire,
            try XCTUnwrap(Date("2026-08-23T23:50:00Z", strategy: .iso8601))
        )
    }
}
