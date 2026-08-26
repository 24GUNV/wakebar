import Foundation
import XCTest
@testable import WakebarCore

final class WakeScheduleTimeOfDayTests: XCTestCase {
    func testWakeTimeOfDayCarriesTheScheduledHourAndMinute() {
        let schedule = Self.fixedSchedule(hour: 6, minute: 45)
        let components = Self.calendar.dateComponents(
            [.hour, .minute],
            from: schedule.wakeTimeOfDay
        )

        XCTAssertEqual(components.hour, 6)
        XCTAssertEqual(components.minute, 45)
    }

    func testApplyWakeTimeReadsOnlyTheHourAndMinute() throws {
        var schedule = Self.fixedSchedule(hour: 6, minute: 45)
        let picked = try XCTUnwrap(
            Self.calendar.date(
                from: DateComponents(year: 2024, month: 3, day: 9, hour: 5, minute: 30)
            )
        )

        schedule.applyWakeTime(picked)

        XCTAssertEqual(schedule.hour, 5)
        XCTAssertEqual(schedule.minute, 30)
    }

    func testWakeTimeRoundTripsThroughThePicker() {
        var schedule = Self.fixedSchedule(hour: 23, minute: 59)
        schedule.applyWakeTime(schedule.wakeTimeOfDay)

        XCTAssertEqual(schedule.hour, 23)
        XCTAssertEqual(schedule.minute, 59)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private static func fixedSchedule(hour: Int, minute: Int) -> WakeSchedule {
        var schedule = WakeSchedule.default
        schedule.followsSystemTimeZone = false
        schedule.timeZoneIdentifier = "UTC"
        schedule.hour = hour
        schedule.minute = minute
        return schedule
    }
}
