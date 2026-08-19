import Foundation

public struct ScheduleCalculator: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    public func nextWakeOccurrence(after date: Date, for schedule: WakeSchedule) -> Date? {
        guard !schedule.selectedWeekdays.isEmpty else { return nil }

        let nextDate = candidateWakeDates(after: date, for: schedule).min()
        guard let nextDate else { return nil }

        if let skippedWakeDate = schedule.skippedWakeDate,
           abs(nextDate.timeIntervalSince(skippedWakeDate)) < 60
        {
            return candidateWakeDates(after: nextDate.addingTimeInterval(60), for: schedule).min()
        }

        return nextDate
    }

    public func nextSessionStart(after date: Date, for schedule: WakeSchedule) -> Date? {
        let leadTime = TimeInterval(schedule.sessionLeadMinutes * 60)
        let wakeSearchDate = date.addingTimeInterval(leadTime)
        return nextWakeOccurrence(after: wakeSearchDate, for: schedule)?.addingTimeInterval(-leadTime)
    }

    private func candidateWakeDates(after date: Date, for schedule: WakeSchedule) -> [Date] {
        var calculationCalendar = calendar
        calculationCalendar.timeZone = schedule.timeZone

        return schedule.selectedWeekdays.compactMap { weekday in
            var components = DateComponents()
            components.calendar = calculationCalendar
            components.timeZone = calculationCalendar.timeZone
            components.weekday = weekday.rawValue
            components.hour = schedule.hour
            components.minute = schedule.minute

            return calculationCalendar.nextDate(
                after: date,
                matching: components,
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: .forward
            )
        }
    }
}
