import Foundation

public struct SchedulePlanner: Sendable {
    private let calculator: ScheduleCalculator
    private let calendar: Calendar
    private let chain: ChainedSessionPlanner

    public init(
        calculator: ScheduleCalculator = ScheduleCalculator(),
        calendar: Calendar = .autoupdatingCurrent,
        chain: ChainedSessionPlanner = ChainedSessionPlanner()
    ) {
        self.calculator = calculator
        self.calendar = calendar
        self.chain = chain
    }

    /// - Parameter windows: what the providers say about the usage windows that
    ///   are open right now. When one is, sessions are spaced by the window the
    ///   provider actually reports and the first one waits for it to close;
    ///   with none, the plan falls back to the assumed five hours.
    public func nextEvents(
        after date: Date,
        for schedule: WakeSchedule,
        windows: [UsageWindow] = []
    ) -> [ScheduledEvent] {
        guard schedule.isEnabled, schedule.isValid else {
            return []
        }

        switch schedule.cadence {
        case .continuous:
            return continuousEvents(after: date, for: schedule, windows: windows)
        case .schedule:
            return scheduledEvents(after: date, for: schedule, windows: windows)
        }
    }

    /// Sessions pinned to the wake: one before it, and — when the schedule asks
    /// for it — more at the window's length until the day's cutoff.
    private func scheduledEvents(
        after date: Date,
        for schedule: WakeSchedule,
        windows: [UsageWindow]
    ) -> [ScheduledEvent] {
        let governing = chain.governingWindow(windows: windows, now: date)

        if let activeWake = calculator.previousWakeOccurrence(
            before: date.addingTimeInterval(1),
            for: schedule
        ) {
            let remainingActiveEvents = events(for: activeWake, schedule: schedule, window: governing)
                .filter { $0.date > date }
            if !remainingActiveEvents.isEmpty {
                return remainingActiveEvents
            }
        }

        guard let nextWake = calculator.nextWakeOccurrence(after: date, for: schedule) else {
            return []
        }

        return events(for: nextWake, schedule: schedule, window: governing).filter { $0.date > date }
    }

    /// How many chained sessions to publish ahead. The popover shows one and the
    /// runner arms the next; anything past that is re-derived on the following
    /// reading, when the provider will have told us something newer.
    private static let continuousHorizon = 4

    /// Sessions pinned to the usage window instead of the clock: one just after
    /// each reset, for as long as the schedule is on.
    ///
    /// There is no cutoff here on purpose. A cutoff exists to stop Wakebar
    /// waking a user's providers through the night before a named morning; a
    /// user who asked for the window to stay open has asked for exactly that.
    private func continuousEvents(
        after date: Date,
        for schedule: WakeSchedule,
        windows: [UsageWindow]
    ) -> [ScheduledEvent] {
        let governing = chain.governingWindow(windows: windows, now: date)
        let step = governing?.duration ?? ChainedSessionPlanner.assumedWindowDuration

        // With a window open the chain waits for its reset. With none open there
        // is nothing to wait for — the next session is the one that opens the
        // window, so it goes now rather than a notional five hours from now.
        let firstStart = chain.nextSession(windows: windows, now: date, cutoff: nil)?.firesAt
            ?? date.addingTimeInterval(chain.buffer)

        let nextWake = calculator.nextWakeOccurrence(after: date, for: schedule)

        var events: [ScheduledEvent] = (0 ..< Self.continuousHorizon).flatMap { index -> [ScheduledEvent] in
            let start = firstStart.addingTimeInterval(step * Double(index))
            let phase: ProviderSessionPhase = index == 0 ? .initial : .refresh(index: index)
            return schedule.providerIDs.map { provider in
                ScheduledEvent(
                    scheduleID: schedule.id,
                    date: start,
                    wakeDate: nextWake ?? start,
                    kind: .providerSession(provider, phase: phase)
                )
            }
        }

        // The alarm still belongs to the calendar. Chaining the sessions changed
        // when the window opens, not when the user wants to be woken.
        if schedule.alarmOnIPhone, let nextWake {
            events.append(
                ScheduledEvent(
                    scheduleID: schedule.id,
                    date: nextWake,
                    wakeDate: nextWake,
                    kind: .phoneAlarm
                )
            )
        }

        return sorted(events).filter { $0.date > date }
    }

    private func events(
        for wakeDate: Date,
        schedule: WakeSchedule,
        window: UsageWindow?
    ) -> [ScheduledEvent] {
        let leadTime = TimeInterval(schedule.sessionLeadMinutes * 60)
        let plannedStart = wakeDate.addingTimeInterval(-leadTime)
        let sessionStarts = sessionStartDates(
            beginningAt: firstSessionStart(plannedStart: plannedStart, window: window),
            wakeDate: wakeDate,
            schedule: schedule,
            window: window
        )

        var events = sessionStarts.enumerated().flatMap { index, sessionStart in
            let phase: ProviderSessionPhase = index == 0 ? .initial : .refresh(index: index)
            return schedule.providerIDs.map { provider in
                ScheduledEvent(
                    scheduleID: schedule.id,
                    date: sessionStart,
                    wakeDate: wakeDate,
                    kind: .providerSession(provider, phase: phase)
                )
            }
        }

        if schedule.alarmOnIPhone {
            events.append(
                ScheduledEvent(
                    scheduleID: schedule.id,
                    date: wakeDate,
                    wakeDate: wakeDate,
                    kind: .phoneAlarm
                )
            )
        }

        return sorted(events)
    }

    private func sorted(_ events: [ScheduledEvent]) -> [ScheduledEvent] {
        events.sorted { lhs, rhs in
            if lhs.date == rhs.date {
                lhs.kind.stableKey < rhs.kind.stableKey
            } else {
                lhs.date < rhs.date
            }
        }
    }

    /// A session sent into an open window does not open a new one, so the first
    /// session waits for the reset.
    ///
    /// The wait is bounded by one window, which is all an open window can have
    /// left. That bound is what keeps a reading taken today from dragging
    /// yesterday's plan — or tomorrow's — onto the wrong day.
    private func firstSessionStart(plannedStart: Date, window: UsageWindow?) -> Date {
        guard let window else { return plannedStart }
        let chained = window.resetsAt.addingTimeInterval(chain.buffer)
        guard chained > plannedStart,
              chained <= plannedStart.addingTimeInterval(window.duration)
        else { return plannedStart }
        return chained
    }

    private func sessionStartDates(
        beginningAt firstSessionStart: Date,
        wakeDate: Date,
        schedule: WakeSchedule,
        window: UsageWindow?
    ) -> [Date] {
        guard schedule.repeatEveryFiveHours else {
            return [firstSessionStart]
        }

        var calculationCalendar = calendar
        calculationCalendar.timeZone = schedule.timeZone

        guard let cutoff = calculationCalendar.date(
            bySettingHour: schedule.repeatUntilHour,
            minute: 0,
            second: 0,
            of: wakeDate
        ) else {
            return [firstSessionStart]
        }

        // Each session opens a window of its own, so the next one is due when
        // that window runs out. The provider's own figure is used when it gave
        // one; five hours is the standing assumption when it did not.
        let step = window?.duration ?? ChainedSessionPlanner.assumedWindowDuration
        var dates = [firstSessionStart]
        var candidate = firstSessionStart.addingTimeInterval(step)

        while candidate <= cutoff {
            dates.append(candidate)
            candidate = candidate.addingTimeInterval(step)
        }

        return dates
    }
}
