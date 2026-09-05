import Foundation
import XCTest
@testable import WakebarCore

final class SchedulePlannerTests: XCTestCase {
    func testPlansOneSessionForEachProvider() throws {
        let calendar = try utcCalendar()
        let calculator = ScheduleCalculator(calendar: calendar)
        let planner = SchedulePlanner(calculator: calculator, calendar: calendar)
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 6))
        )
        let schedule = makeSchedule()

        let events = planner.nextEvents(after: now, for: schedule)

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].date, events[1].date)
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

    func testCodexDoesNotReceiveFiveHourRefreshes() throws {
        let calendar = try utcCalendar()
        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 6))
        )
        var schedule = makeSchedule()
        schedule.includeClaude = false
        schedule.repeatEveryFiveHours = true
        schedule.repeatUntilHour = 19

        let events = planner.nextEvents(after: now, for: schedule)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(firstStart(for: .codex, in: events), events.first?.date)
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

        let first = try XCTUnwrap(planner.nextEvents(after: now, for: schedule).first)

        XCTAssertEqual(first.date, now.addingTimeInterval(ChainedSessionPlanner.resetBuffer))
    }

    /// A day selection gates the fixed schedule, not the continuous chain.
    func testContinuousIsValidWithoutSelectedWeekdays() throws {
        var schedule = makeSchedule()
        schedule.selectedWeekdays = []

        XCTAssertFalse(schedule.isValid)
        schedule.cadence = .continuous
        XCTAssertTrue(schedule.isValid)
    }

    func testContinuousCadenceChainsEachProviderOffItsOwnReset() throws {
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

    /// A Codex plan that reports only a weekly cap is woken once, after that
    /// cap resets, so the new week starts at the reset and not at the user's
    /// first request days later.
    func testContinuousCadenceWakesWeeklyOnlyCodexOnceAfterItsReset() throws {
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
        schedule.includeClaude = false

        let weeklyReset = now.addingTimeInterval(3 * 24 * 60 * 60)
        let events = planner.nextEvents(
            after: now,
            for: schedule,
            windows: [
                openWindow(
                    resetsAt: weeklyReset,
                    observedAt: now,
                    duration: 7 * 24 * 60 * 60,
                    provider: .codex
                ),
            ]
        )

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(
            firstStart(for: .codex, in: events),
            weeklyReset.addingTimeInterval(ChainedSessionPlanner.resetBuffer)
        )
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
        let schedule = makeSchedule()

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

    /// Codex on a weekly-only plan reports a limit but never a session window.
    /// Assuming five hours for it would march sessions at a reset that never
    /// arrives, so it gets one wake at the weekly reset while Claude chains.
    func testContinuousWakesAWeeklyOnlyProviderOnceAtItsReset() throws {
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
        let weeklyReset = now.addingTimeInterval(3 * 24 * 60 * 60)

        let events = planner.nextEvents(
            after: now,
            for: schedule,
            windows: [
                openWindow(
                    resetsAt: weeklyReset,
                    observedAt: now,
                    duration: 7 * 24 * 60 * 60,
                    provider: .codex
                ),
                openWindow(resetsAt: now.addingTimeInterval(90 * 60), observedAt: now),
            ]
        )

        let codexStarts = events.compactMap { event -> Date? in
            guard case .providerSession(.codex, _) = event.kind else { return nil }
            return event.date
        }
        XCTAssertEqual(codexStarts, [weeklyReset.addingTimeInterval(ChainedSessionPlanner.resetBuffer)])
        XCTAssertTrue(events.contains { event in
            if case .providerSession(.claude, _) = event.kind { return true }
            return false
        })
    }

    func testContinuousDoesNotAssumeAFiveHourCodexWindow() throws {
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
        schedule.includeClaude = false

        let events = planner.nextEvents(after: now, for: schedule, windows: [])

        XCTAssertTrue(events.isEmpty)
    }

    /// A session sent to a provider that was never set up does nothing, so the
    /// popover must not count down to it. The provider row already says "Needs
    /// setup" and the footer already offers to fix it.
    func testSessionsAreNotPlannedForProvidersThatAreNotSetUp() throws {
        let calendar = try utcCalendar()
        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        let now = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 9))
        )
        let schedule = makeSchedule()

        let events = planner.nextEvents(
            after: now,
            for: schedule,
            windows: [],
            readyProviders: [.claude]
        )

        let providers = events.compactMap { event -> ProviderID? in
            guard case .providerSession(let provider, _) = event.kind else { return nil }
            return provider
        }
        XCTAssertFalse(providers.isEmpty)
        XCTAssertFalse(providers.contains(.codex))
        XCTAssertTrue(providers.contains(.claude))
    }

}
