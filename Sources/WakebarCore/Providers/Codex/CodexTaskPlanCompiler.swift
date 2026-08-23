import Foundation

public struct CodexTaskPlanCompiler: Sendable {
    public static let prompt = "hi"

    private let slotCompiler: RecurringSessionSlotCompiler

    public init(slotCompiler: RecurringSessionSlotCompiler = RecurringSessionSlotCompiler()) {
        self.slotCompiler = slotCompiler
    }

    public func compile(schedule: WakeSchedule) -> [CodexTaskSpec] {
        guard schedule.includeCodex else { return [] }

        let prefix = Self.namePrefix(for: schedule)
        return codexSlots(for: schedule).map { slot in
            CodexTaskSpec(
                name: "\(prefix) Morning",
                schedule: recurrenceRule(for: slot),
                timeZoneIdentifier: schedule.timeZone.identifier,
                prompt: Self.prompt,
                enabled: schedule.isEnabled,
                weekdays: slot.weekdays,
                hour: slot.hour,
                minute: slot.minute
            )
        }
    }

    public func nextFire(after date: Date, schedule: WakeSchedule) -> Date? {
        guard schedule.includeCodex else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = schedule.timeZone

        return codexSlots(for: schedule).flatMap { slot in
            slot.weekdays.compactMap { weekday in
                var components = DateComponents()
                components.calendar = calendar
                components.timeZone = calendar.timeZone
                components.weekday = weekday.rawValue
                components.hour = slot.hour
                components.minute = slot.minute
                return calendar.nextDate(
                    after: date,
                    matching: components,
                    matchingPolicy: .nextTime,
                    repeatedTimePolicy: .first,
                    direction: .forward
                )
            }
        }.min()
    }

    public static func namePrefix(for schedule: WakeSchedule) -> String {
        "Wakebar · \(schedule.id.uuidString.prefix(8).uppercased()) ·"
    }

    /// Codex has a weekly limit, not a five-hour session window. Its task opens
    /// the named work period once; the five-hour refresh slots apply to Claude.
    private func codexSlots(for schedule: WakeSchedule) -> [RecurringSessionSlot] {
        slotCompiler.slots(for: schedule).filter { slot in
            if case .initial = slot.phase { true } else { false }
        }
    }

    private func recurrenceRule(for slot: RecurringSessionSlot) -> String {
        let weekdays = Weekday.displayOrder
            .filter(slot.weekdays.contains)
            .map(rfc5545Weekday)
            .joined(separator: ",")
        return "RRULE:FREQ=WEEKLY;BYDAY=\(weekdays);BYHOUR=\(slot.hour);BYMINUTE=\(slot.minute);BYSECOND=0"
    }

    private func rfc5545Weekday(_ weekday: Weekday) -> String {
        switch weekday {
        case .monday: "MO"
        case .tuesday: "TU"
        case .wednesday: "WE"
        case .thursday: "TH"
        case .friday: "FR"
        case .saturday: "SA"
        case .sunday: "SU"
        }
    }
}
