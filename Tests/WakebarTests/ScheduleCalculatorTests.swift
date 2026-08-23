import Foundation
import XCTest
@testable import WakebarCore

final class ScheduleCalculatorTests: XCTestCase {
    func testWeekdayScheduleSkipsWeekend() throws {
        let calendar = try utcCalendar()
        let calculator = ScheduleCalculator(calendar: calendar)
        let fridayAfternoon = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 17))
        )
        let schedule = makeSchedule()

        let nextWake = try XCTUnwrap(calculator.nextWakeOccurrence(after: fridayAfternoon, for: schedule))
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextWake)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 8)
        XCTAssertEqual(components.day, 24)
        XCTAssertEqual(components.hour, 7)
        XCTAssertEqual(components.minute, 0)
    }

    func testSessionStartUsesConfiguredLeadTime() throws {
        let calendar = try utcCalendar()
        let calculator = ScheduleCalculator(calendar: calendar)
        let morning = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 6))
        )
        let schedule = makeSchedule()

        let nextStart = try XCTUnwrap(calculator.nextSessionStart(after: morning, for: schedule))
        let components = calendar.dateComponents([.day, .hour, .minute], from: nextStart)

        XCTAssertEqual(components.day, 20)
        XCTAssertEqual(components.hour, 6)
        XCTAssertEqual(components.minute, 50)
    }

    func testMissedSessionStartMovesToNextSelectedDay() throws {
        let calendar = try utcCalendar()
        let calculator = ScheduleCalculator(calendar: calendar)
        let afterPrime = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 6, minute: 55))
        )
        let schedule = makeSchedule()

        let nextStart = try XCTUnwrap(calculator.nextSessionStart(after: afterPrime, for: schedule))
        let components = calendar.dateComponents([.day, .hour, .minute], from: nextStart)

        XCTAssertEqual(components.day, 21)
        XCTAssertEqual(components.hour, 6)
        XCTAssertEqual(components.minute, 50)
    }

    func testSkippedWakeMovesToFollowingOccurrence() throws {
        let calendar = try utcCalendar()
        let calculator = ScheduleCalculator(calendar: calendar)
        let thursdayMorning = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 6))
        )
        let skippedWake = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 7))
        )
        var schedule = makeSchedule()
        schedule.skippedWakeDate = skippedWake

        let nextWake = try XCTUnwrap(calculator.nextWakeOccurrence(after: thursdayMorning, for: schedule))
        let components = calendar.dateComponents([.day, .hour, .minute], from: nextWake)

        XCTAssertEqual(components.day, 21)
        XCTAssertEqual(components.hour, 7)
        XCTAssertEqual(components.minute, 0)
    }

    func testFixedTimeZoneControlsWallClockTime() throws {
        let calendar = try utcCalendar()
        let calculator = ScheduleCalculator(calendar: calendar)
        let afterStartInTokyo = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 0))
        )
        var schedule = makeSchedule()
        schedule.selectedWeekdays = Set(Weekday.allCases)
        schedule.followsSystemTimeZone = false
        schedule.timeZoneIdentifier = "Asia/Tokyo"

        let nextWake = try XCTUnwrap(calculator.nextWakeOccurrence(after: afterStartInTokyo, for: schedule))
        var tokyoCalendar = Calendar(identifier: .gregorian)
        tokyoCalendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let components = tokyoCalendar.dateComponents([.day, .hour, .minute], from: nextWake)

        XCTAssertEqual(components.day, 21)
        XCTAssertEqual(components.hour, 7)
        XCTAssertEqual(components.minute, 0)
    }

    private func makeSchedule() -> WakeSchedule {
        WakeSchedule(
            id: UUID(),
            isEnabled: true,
            hour: 7,
            minute: 0,
            selectedWeekdays: Weekday.workweek,
            sessionLeadMinutes: 10,
            repeatEveryFiveHours: false,
            repeatUntilHour: 19,
            includeClaude: true,
            includeCodex: true,
            claudeBackend: .providerCloud,
            codexBackend: .providerCloud,
            followsSystemTimeZone: false,
            timeZoneIdentifier: "UTC"
        )
    }

    private func utcCalendar() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        return calendar
    }
}
