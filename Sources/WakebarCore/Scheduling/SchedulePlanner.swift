import Foundation

public struct SchedulePlanner: Sendable {
    private let calculator: ScheduleCalculator
    private let calendar: Calendar

    public init(
        calculator: ScheduleCalculator = ScheduleCalculator(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.calculator = calculator
        self.calendar = calendar
    }

    public func nextEvents(after date: Date, for schedule: WakeSchedule) -> [ScheduledEvent] {
        guard schedule.isEnabled, schedule.isValid else {
            return []
        }

        if let activeWake = calculator.previousWakeOccurrence(
            before: date.addingTimeInterval(1),
            for: schedule
        ) {
            let remainingActiveEvents = events(for: activeWake, schedule: schedule).filter { $0.date > date }
            if !remainingActiveEvents.isEmpty {
                return remainingActiveEvents
            }
        }

        guard let nextWake = calculator.nextWakeOccurrence(after: date, for: schedule) else {
            return []
        }

        return events(for: nextWake, schedule: schedule).filter { $0.date > date }
    }

    private func events(for wakeDate: Date, schedule: WakeSchedule) -> [ScheduledEvent] {
        let leadTime = TimeInterval(schedule.sessionLeadMinutes * 60)
        let firstSessionStart = wakeDate.addingTimeInterval(-leadTime)
        let sessionStarts = sessionStartDates(beginningAt: firstSessionStart, wakeDate: wakeDate, schedule: schedule)

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

        return events.sorted { lhs, rhs in
            if lhs.date == rhs.date {
                lhs.kind.stableKey < rhs.kind.stableKey
            } else {
                lhs.date < rhs.date
            }
        }
    }

    private func sessionStartDates(
        beginningAt firstSessionStart: Date,
        wakeDate: Date,
        schedule: WakeSchedule
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

        var dates = [firstSessionStart]
        var candidate = firstSessionStart.addingTimeInterval(5 * 60 * 60)

        while candidate <= cutoff {
            dates.append(candidate)
            candidate = candidate.addingTimeInterval(5 * 60 * 60)
        }

        return dates
    }
}
