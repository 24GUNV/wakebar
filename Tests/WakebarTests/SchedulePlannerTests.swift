import Foundation
import XCTest
@testable import WakebarCore

final class SchedulePlannerTests: XCTestCase {
    func testPlansProviderSessionsBeforePhoneAlarm() throws {
        let calendar = try utcCalendar()
        let calculator = ScheduleCalculator(calendar: calendar)
        let planner = SchedulePlanner(calculator: calculator, calendar: calendar)
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 6))
        )
        let schedule = makeSchedule()

        let events = planner.nextEvents(after: now, for: schedule)

        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0].date, events[1].date)
        XCTAssertLessThan(events[0].date, events[2].date)
        XCTAssertEqual(events[2].kind, .phoneAlarm)
    }

    func testFiveHourRefreshesStopAtConfiguredHour() throws {
        let calendar = try utcCalendar()
        let calculator = ScheduleCalculator(calendar: calendar)
        let planner = SchedulePlanner(calculator: calculator, calendar: calendar)
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 6))
        )
        var schedule = makeSchedule()
        schedule.includeCodex = false
        schedule.alarmOnIPhone = false
        schedule.repeatEveryFiveHours = true
        schedule.repeatUntilHour = 19

        let events = planner.nextEvents(after: now, for: schedule)
        let times = events.map { calendar.dateComponents([.hour, .minute], from: $0.date) }

        XCTAssertEqual(times.count, 3)
        XCTAssertEqual(times[0].hour, 6)
        XCTAssertEqual(times[0].minute, 50)
        XCTAssertEqual(times[1].hour, 11)
        XCTAssertEqual(times[1].minute, 50)
        XCTAssertEqual(times[2].hour, 16)
        XCTAssertEqual(times[2].minute, 50)
    }

    func testDisabledSchedulePlansNothing() throws {
        let calendar = try utcCalendar()
        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        var schedule = makeSchedule()
        schedule.isEnabled = false

        XCTAssertTrue(planner.nextEvents(after: .now, for: schedule).isEmpty)
    }

    func testKeepsTodaysAlarmAfterInitialSessionTimePasses() throws {
        let calendar = try utcCalendar()
        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 6, minute: 55))
        )

        let events = planner.nextEvents(after: now, for: makeSchedule())

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .phoneAlarm)
        XCTAssertEqual(calendar.component(.hour, from: events[0].date), 7)
    }

    func testRelaunchDuringRefreshChainKeepsRemainingRefreshes() throws {
        let calendar = try utcCalendar()
        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 8))
        )
        var schedule = makeSchedule()
        schedule.includeCodex = false
        schedule.alarmOnIPhone = false
        schedule.repeatEveryFiveHours = true

        let events = planner.nextEvents(after: now, for: schedule)
        let hours = events.map { calendar.component(.hour, from: $0.date) }

        XCTAssertEqual(hours, [11, 16])
    }

    func testSkippedCurrentWakeRemovesItsRefreshChain() throws {
        let calendar = try utcCalendar()
        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 8))
        )
        var schedule = makeSchedule()
        schedule.includeCodex = false
        schedule.alarmOnIPhone = false
        schedule.repeatEveryFiveHours = true
        schedule.skippedWakeDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 7))
        )

        let events = planner.nextEvents(after: now, for: schedule)
        let firstEvent = try XCTUnwrap(events.first)
        let components = calendar.dateComponents([.day, .hour, .minute], from: firstEvent.date)

        XCTAssertEqual(components.day, 21)
        XCTAssertEqual(components.hour, 6)
        XCTAssertEqual(components.minute, 50)
    }

    private func makeSchedule() -> WakeSchedule {
        WakeSchedule(
            id: UUID(),
            isEnabled: true,
            hour: 7,
            minute: 0,
            selectedWeekdays: Weekday.workweek,
            sessionLeadMinutes: 10,
            alarmOnIPhone: true,
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
