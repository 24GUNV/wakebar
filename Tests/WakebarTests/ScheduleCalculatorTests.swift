import Foundation
import Testing
@testable import WakebarCore

struct ScheduleCalculatorTests {
    @Test
    func weekdayScheduleSkipsWeekend() throws {
        let calendar = try utcCalendar()
        let calculator = ScheduleCalculator(calendar: calendar)
        let fridayAfternoon = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 21, hour: 17))
        )
        let schedule = makeSchedule()

        let nextWake = try #require(calculator.nextWakeOccurrence(after: fridayAfternoon, for: schedule))
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextWake)

        #expect(components.year == 2026)
        #expect(components.month == 8)
        #expect(components.day == 24)
        #expect(components.hour == 7)
        #expect(components.minute == 0)
    }

    @Test
    func sessionStartUsesConfiguredLeadTime() throws {
        let calendar = try utcCalendar()
        let calculator = ScheduleCalculator(calendar: calendar)
        let morning = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 6))
        )
        let schedule = makeSchedule()

        let nextStart = try #require(calculator.nextSessionStart(after: morning, for: schedule))
        let components = calendar.dateComponents([.day, .hour, .minute], from: nextStart)

        #expect(components.day == 20)
        #expect(components.hour == 6)
        #expect(components.minute == 50)
    }

    @Test
    func missedSessionStartMovesToNextSelectedDay() throws {
        let calendar = try utcCalendar()
        let calculator = ScheduleCalculator(calendar: calendar)
        let afterPrime = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 6, minute: 55))
        )
        let schedule = makeSchedule()

        let nextStart = try #require(calculator.nextSessionStart(after: afterPrime, for: schedule))
        let components = calendar.dateComponents([.day, .hour, .minute], from: nextStart)

        #expect(components.day == 21)
        #expect(components.hour == 6)
        #expect(components.minute == 50)
    }

    @Test
    func skippedWakeMovesToFollowingOccurrence() throws {
        let calendar = try utcCalendar()
        let calculator = ScheduleCalculator(calendar: calendar)
        let thursdayMorning = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 6))
        )
        let skippedWake = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 7))
        )
        var schedule = makeSchedule()
        schedule.skippedWakeDate = skippedWake

        let nextWake = try #require(calculator.nextWakeOccurrence(after: thursdayMorning, for: schedule))
        let components = calendar.dateComponents([.day, .hour, .minute], from: nextWake)

        #expect(components.day == 21)
        #expect(components.hour == 7)
        #expect(components.minute == 0)
    }

    @Test
    func fixedTimeZoneControlsWallClockTime() throws {
        let calendar = try utcCalendar()
        let calculator = ScheduleCalculator(calendar: calendar)
        let afterStartInTokyo = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 0))
        )
        var schedule = makeSchedule()
        schedule.selectedWeekdays = Set(Weekday.allCases)
        schedule.followsSystemTimeZone = false
        schedule.timeZoneIdentifier = "Asia/Tokyo"

        let nextWake = try #require(calculator.nextWakeOccurrence(after: afterStartInTokyo, for: schedule))
        var tokyoCalendar = Calendar(identifier: .gregorian)
        tokyoCalendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let components = tokyoCalendar.dateComponents([.day, .hour, .minute], from: nextWake)

        #expect(components.day == 21)
        #expect(components.hour == 7)
        #expect(components.minute == 0)
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
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        return calendar
    }
}
