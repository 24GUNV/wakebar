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

    /// A session sent while the window is still open does not open a new one,
    /// so the first session waits for the reported reset instead of firing at
    /// the time the fixed slot assumed.
    func testOpenWindowDelaysTheFirstSession() throws {
        let calendar = try utcCalendar()
        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 6))
        )
        var schedule = makeSchedule()
        schedule.includeCodex = false
        schedule.alarmOnIPhone = false
        let resetsAt = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 7, minute: 20))
        )

        let events = planner.nextEvents(
            after: now,
            for: schedule,
            windows: [openWindow(resetsAt: resetsAt, observedAt: now)]
        )

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].date, resetsAt.addingTimeInterval(60))
    }

    /// The chain must never start the day early. A window that closes at three
    /// in the morning is not a reason to wake the providers then.
    func testWindowClosingBeforeThePlannedStartChangesNothing() throws {
        let calendar = try utcCalendar()
        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 2))
        )
        var schedule = makeSchedule()
        schedule.includeCodex = false
        schedule.alarmOnIPhone = false
        let resetsAt = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 3))
        )

        let events = planner.nextEvents(
            after: now,
            for: schedule,
            windows: [openWindow(resetsAt: resetsAt, observedAt: now)]
        )
        let time = calendar.dateComponents([.hour, .minute], from: try XCTUnwrap(events.first?.date))

        XCTAssertEqual(time.hour, 6)
        XCTAssertEqual(time.minute, 50)
    }

    /// Refreshes are spaced by the window the provider actually reports, not by
    /// the five hours the fixed slots assume.
    func testRefreshesUseTheReportedWindowLength() throws {
        let calendar = try utcCalendar()
        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 6))
        )
        var schedule = makeSchedule()
        schedule.includeCodex = false
        schedule.alarmOnIPhone = false
        schedule.repeatEveryFiveHours = true
        schedule.repeatUntilHour = 19
        let resetsAt = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 7))
        )

        let events = planner.nextEvents(
            after: now,
            for: schedule,
            windows: [openWindow(resetsAt: resetsAt, observedAt: now, duration: 4 * 60 * 60)]
        )
        let times = events.map { calendar.dateComponents([.hour, .minute], from: $0.date) }

        XCTAssertEqual(times.count, 3)
        XCTAssertEqual(times.map(\.hour), [7, 11, 15])
        XCTAssertEqual(Set(times.map(\.minute)), [1])
    }

    /// A weekly cap is not a window a session can reopen, so the plan ignores it.
    func testNonSessionWindowsAreIgnored() throws {
        let calendar = try utcCalendar()
        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 6))
        )
        var schedule = makeSchedule()
        schedule.includeCodex = false
        schedule.alarmOnIPhone = false
        let resetsAt = now.addingTimeInterval(3 * 24 * 60 * 60)

        let events = planner.nextEvents(
            after: now,
            for: schedule,
            windows: [openWindow(resetsAt: resetsAt, observedAt: now, duration: 10080 * 60)]
        )
        let time = calendar.dateComponents([.hour, .minute], from: try XCTUnwrap(events.first?.date))

        XCTAssertEqual(time.hour, 6)
        XCTAssertEqual(time.minute, 50)
    }

    // MARK: - Continuous cadence

    func testContinuousSessionsChainOffTheReportedWindow() throws {
        let calendar = try utcCalendar()
        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 9))
        )
        var schedule = makeSchedule()
        schedule.cadence = .continuous
        schedule.includeCodex = false
        schedule.alarmOnIPhone = false

        let resetsAt = now.addingTimeInterval(90 * 60)
        let events = planner.nextEvents(
            after: now,
            for: schedule,
            windows: [openWindow(resetsAt: resetsAt, observedAt: now)]
        )
        let starts = events.map(\.date)

        XCTAssertEqual(starts.first, resetsAt.addingTimeInterval(ChainedSessionPlanner.resetBuffer))
        // Each session opens a window of its own, so the chain steps by the
        // window the provider reported rather than by a wall-clock hour.
        XCTAssertEqual(
            starts.last,
            try XCTUnwrap(starts.first).addingTimeInterval(3 * 5 * 60 * 60)
        )
    }

    /// The cutoff is a schedule-cadence idea. A user who asked for the window to
    /// stay open has asked for it to stay open overnight too.
    func testContinuousSessionsIgnoreTheDailyCutoff() throws {
        let calendar = try utcCalendar()
        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 18))
        )
        var schedule = makeSchedule()
        schedule.cadence = .continuous
        schedule.includeCodex = false
        schedule.alarmOnIPhone = false
        schedule.repeatUntilHour = 19

        let events = planner.nextEvents(after: now, for: schedule)

        XCTAssertFalse(events.isEmpty)
        XCTAssertTrue(events.contains { $0.date > now.addingTimeInterval(6 * 60 * 60) })
    }

    /// With nothing open there is no reset to wait for, so the session that
    /// opens the window goes now rather than a notional five hours out.
    func testContinuousFiresPromptlyWhenNoWindowIsOpen() throws {
        let calendar = try utcCalendar()
        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 12))
        )
        var schedule = makeSchedule()
        schedule.cadence = .continuous
        schedule.includeCodex = false
        schedule.alarmOnIPhone = false

        let first = try XCTUnwrap(planner.nextEvents(after: now, for: schedule).first)

        XCTAssertEqual(first.date, now.addingTimeInterval(ChainedSessionPlanner.resetBuffer))
    }

    /// Chaining the sessions changed when the window opens, not when the user
    /// wants to be woken.
    func testContinuousStillPlansThePhoneAlarmOnSchedule() throws {
        let calendar = try utcCalendar()
        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 12))
        )
        var schedule = makeSchedule()
        schedule.cadence = .continuous

        let events = planner.nextEvents(after: now, for: schedule)
        let alarm = try XCTUnwrap(events.first { $0.kind == .phoneAlarm })

        XCTAssertEqual(calendar.dateComponents([.hour], from: alarm.date).hour, 7)
    }

    /// A day selection gates the alarm, not the chain.
    func testContinuousIsValidWithoutSelectedWeekdays() throws {
        var schedule = makeSchedule()
        schedule.selectedWeekdays = []

        XCTAssertFalse(schedule.isValid)
        schedule.cadence = .continuous
        XCTAssertTrue(schedule.isValid)
    }

    /// The whole point of chaining, and the thing a single shared "soonest
    /// window" got wrong: a session fired into a window that is still open does
    /// not reopen it, so a provider chained off someone else's reset silently
    /// loses its place.
    func testEachProviderChainsOffItsOwnWindow() throws {
        let calendar = try utcCalendar()
        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 9))
        )
        var schedule = makeSchedule()
        schedule.cadence = .continuous
        schedule.alarmOnIPhone = false

        let claudeReset = now.addingTimeInterval(60 * 60)
        let codexReset = now.addingTimeInterval(4 * 60 * 60)
        let events = planner.nextEvents(
            after: now,
            for: schedule,
            windows: [
                openWindow(resetsAt: claudeReset, observedAt: now),
                openWindow(resetsAt: codexReset, observedAt: now, provider: .codex),
            ]
        )

        let buffer = ChainedSessionPlanner.resetBuffer
        XCTAssertEqual(firstStart(for: .claude, in: events), claudeReset.addingTimeInterval(buffer))
        XCTAssertEqual(firstStart(for: .codex, in: events), codexReset.addingTimeInterval(buffer))
    }

    /// The same drift under the schedule cadence, where the clamp used to be
    /// applied once for every provider.
    func testScheduledSessionsClampPerProvider() throws {
        let calendar = try utcCalendar()
        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 5))
        )
        var schedule = makeSchedule()
        schedule.alarmOnIPhone = false

        // Claude's window is still open past the planned start, so its session
        // waits. Codex has nothing open, so its session keeps the planned time.
        let claudeReset = now.addingTimeInterval(3 * 60 * 60)
        let events = planner.nextEvents(
            after: now,
            for: schedule,
            windows: [openWindow(resetsAt: claudeReset, observedAt: now)]
        )

        let claude = try XCTUnwrap(firstStart(for: .claude, in: events))
        let codex = try XCTUnwrap(firstStart(for: .codex, in: events))
        XCTAssertEqual(claude, claudeReset.addingTimeInterval(ChainedSessionPlanner.resetBuffer))
        XCTAssertLessThan(codex, claude)
        XCTAssertEqual(calendar.dateComponents([.hour, .minute], from: codex).hour, 6)
    }

    private func firstStart(for provider: ProviderID, in events: [ScheduledEvent]) -> Date? {
        events.first { event in
            if case .providerSession(provider, _) = event.kind { true } else { false }
        }?.date
    }

    private func openWindow(
        resetsAt: Date,
        observedAt: Date,
        duration: TimeInterval = 5 * 60 * 60,
        provider: ProviderID = .claude
    ) -> UsageWindow {
        UsageWindow(
            provider: provider,
            duration: duration,
            resetsAt: resetsAt,
            observedAt: observedAt,
            confidence: .reported
        )
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
