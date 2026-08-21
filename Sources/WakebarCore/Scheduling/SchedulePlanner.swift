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
    /// - Parameter readyProviders: which providers have a confirmed setup and can
    ///   actually receive a session. Nil means readiness is unknown — the planner
    ///   then plans for everything the schedule selects, which is what the pure
    ///   scheduling tests want. Passing a set narrows the plan: a session sent to
    ///   a provider that was never set up does nothing, and publishing it anyway
    ///   makes the popover count down to an event that cannot happen.
    public func nextEvents(
        after date: Date,
        for schedule: WakeSchedule,
        windows: [UsageWindow] = [],
        readyProviders: Set<ProviderID>? = nil
    ) -> [ScheduledEvent] {
        guard schedule.isEnabled, schedule.isValid else {
            return []
        }

        let providers = readyProviders.map { ready in
            schedule.providerIDs.filter(ready.contains)
        } ?? schedule.providerIDs

        switch schedule.cadence {
        case .continuous:
            return continuousEvents(after: date, for: schedule, providers: providers, windows: windows)
        case .schedule:
            return scheduledEvents(after: date, for: schedule, providers: providers, windows: windows)
        }
    }

    /// Sessions pinned to the wake: one before it, and — when the schedule asks
    /// for it — more at the window's length until the day's cutoff.
    private func scheduledEvents(
        after date: Date,
        for schedule: WakeSchedule,
        providers: [ProviderID],
        windows: [UsageWindow]
    ) -> [ScheduledEvent] {
        if let activeWake = calculator.previousWakeOccurrence(
            before: date.addingTimeInterval(1),
            for: schedule
        ) {
            let remainingActiveEvents = events(
                for: activeWake,
                schedule: schedule,
                providers: providers,
                windows: windows,
                now: date
            )
            .filter { $0.date > date }
            if !remainingActiveEvents.isEmpty {
                return remainingActiveEvents
            }
        }

        guard let nextWake = calculator.nextWakeOccurrence(after: date, for: schedule) else {
            return []
        }

        return events(for: nextWake, schedule: schedule, providers: providers, windows: windows, now: date)
            .filter { $0.date > date }
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
        providers: [ProviderID],
        windows: [UsageWindow]
    ) -> [ScheduledEvent] {
        let nextWake = calculator.nextWakeOccurrence(after: date, for: schedule)

        var events: [ScheduledEvent] = providers.flatMap { provider -> [ScheduledEvent] in
            // A provider that reports its limits but never a session window has
            // no reset to chain to — a Codex plan carrying only a weekly cap is
            // the case. Assuming five hours for it would march sessions at a
            // window that does not exist. Silence is the honest plan; the
            // schedule cadence still covers that provider before each wake.
            let reported = windows.filter { $0.provider == provider }
            guard reported.isEmpty || reported.contains(where: \.isSessionWindow) else {
                return []
            }

            let window = chain.governingWindow(windows: windows, now: date, provider: provider)
            let step = window?.duration ?? ChainedSessionPlanner.assumedWindowDuration

            // With a window open the chain waits for that provider's reset. With
            // none open there is nothing to wait for — the next session is the
            // one that opens the window, so it goes now rather than a notional
            // five hours from now.
            let firstStart = window.map { $0.resetsAt.addingTimeInterval(chain.buffer) }
                ?? date.addingTimeInterval(chain.buffer)

            return (0 ..< Self.continuousHorizon).map { index in
                ScheduledEvent(
                    scheduleID: schedule.id,
                    date: firstStart.addingTimeInterval(step * Double(index)),
                    wakeDate: nextWake ?? firstStart,
                    kind: .providerSession(
                        provider,
                        phase: index == 0 ? .initial : .refresh(index: index)
                    )
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
        providers: [ProviderID],
        windows: [UsageWindow],
        now: Date
    ) -> [ScheduledEvent] {
        let leadTime = TimeInterval(schedule.sessionLeadMinutes * 60)
        let plannedStart = wakeDate.addingTimeInterval(-leadTime)

        // Each provider is clamped against its own open window. Two providers
        // whose windows have drifted apart get two different start times, which
        // is the only way both actually open a fresh window.
        var events = providers.flatMap { provider -> [ScheduledEvent] in
            let window = chain.governingWindow(windows: windows, now: now, provider: provider)
            let sessionStarts = sessionStartDates(
                beginningAt: firstSessionStart(plannedStart: plannedStart, window: window),
                wakeDate: wakeDate,
                schedule: schedule,
                window: window
            )

            return sessionStarts.enumerated().map { index, sessionStart in
                ScheduledEvent(
                    scheduleID: schedule.id,
                    date: sessionStart,
                    wakeDate: wakeDate,
                    kind: .providerSession(
                        provider,
                        phase: index == 0 ? .initial : .refresh(index: index)
                    )
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
