import Foundation
import XCTest
@testable import WakebarCore

final class RoutinePlanCompilerTests: XCTestCase {
    func testCompilesWakeAndRefreshSlotsToUTC() throws {
        var schedule = WakeSchedule.default
        schedule.isEnabled = true
        schedule.repeatEveryFiveHours = true
        schedule.repeatUntilHour = 19
        schedule.followsSystemTimeZone = false
        schedule.timeZoneIdentifier = "Asia/Bangkok"

        let plan = RoutinePlanCompiler().compile(
            schedule: schedule,
            referenceDate: try date("2026-01-15T00:00:00Z")
        )

        XCTAssertEqual(plan.count, 3)
        XCTAssertEqual(plan.map(\.cronExpression), [
            "50 23 * * 0,1,2,3,4",
            "50 4 * * 1,2,3,4,5",
            "50 9 * * 1,2,3,4,5",
        ])
        XCTAssertEqual(plan.map(\.name), [
            "\(RoutinePlanCompiler.namePrefix(for: schedule)) Morning",
            "\(RoutinePlanCompiler.namePrefix(for: schedule)) Refresh 1",
            "\(RoutinePlanCompiler.namePrefix(for: schedule)) Refresh 2",
        ])
        XCTAssertTrue(plan.allSatisfy(\.enabled))
        XCTAssertTrue(plan.allSatisfy { $0.prompt == RoutinePlanCompiler.prompt })
        XCTAssertTrue(plan.allSatisfy { $0.prompt.contains("Do not use tools") })
    }

    func testDSTOffsetChangesUTCStartWithoutChangingLocalSchedule() throws {
        var schedule = WakeSchedule.default
        schedule.isEnabled = true
        schedule.selectedWeekdays = [.monday]
        schedule.followsSystemTimeZone = false
        schedule.timeZoneIdentifier = "America/New_York"

        let compiler = RoutinePlanCompiler()
        let winter = compiler.compile(
            schedule: schedule,
            referenceDate: try date("2026-01-15T00:00:00Z")
        )
        let summer = compiler.compile(
            schedule: schedule,
            referenceDate: try date("2026-07-15T00:00:00Z")
        )

        XCTAssertEqual(winter.map(\.cronExpression), ["50 11 * * 1"])
        XCTAssertEqual(summer.map(\.cronExpression), ["50 10 * * 1"])
    }

    func testUTCConversionMovesWeekdayAcrossMidnight() throws {
        var schedule = WakeSchedule.default
        schedule.isEnabled = true
        schedule.hour = 0
        schedule.minute = 10
        schedule.sessionLeadMinutes = 10
        schedule.selectedWeekdays = [.monday]
        schedule.followsSystemTimeZone = false
        schedule.timeZoneIdentifier = "Asia/Bangkok"

        let plan = RoutinePlanCompiler().compile(
            schedule: schedule,
            referenceDate: try date("2026-01-15T00:00:00Z")
        )

        XCTAssertEqual(plan.map(\.cronExpression), ["0 17 * * 0"])
    }

    func testRemovingClaudeProducesEmptyPlanForReconciliation() throws {
        var schedule = WakeSchedule.default
        schedule.includeClaude = false

        let plan = RoutinePlanCompiler().compile(
            schedule: schedule,
            referenceDate: try date("2026-01-15T00:00:00Z")
        )

        XCTAssertTrue(plan.isEmpty)
    }

    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: value))
    }
}
