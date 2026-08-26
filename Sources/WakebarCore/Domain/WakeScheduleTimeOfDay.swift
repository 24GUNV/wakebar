import Foundation

extension WakeSchedule {
    /// Time pickers bind to a `Date`, so the wake hour and minute ride on a fixed reference day.
    public var wakeTimeOfDay: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(
            from: DateComponents(
                year: 2001,
                month: 1,
                day: 1,
                hour: hour,
                minute: minute
            )
        ) ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    /// Only the hour and minute are read; the picker's reference day carries no meaning.
    public mutating func applyWakeTime(_ date: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        hour = components.hour ?? hour
        minute = components.minute ?? minute
    }
}
