import Foundation

public struct RoutinePlanCompiler: Sendable {
    public static let prompt = "Reply only with hi. Do not use tools, edit files, publish artifacts, or request permissions."

    private let slotCompiler: RecurringSessionSlotCompiler

    public init(slotCompiler: RecurringSessionSlotCompiler = RecurringSessionSlotCompiler()) {
        self.slotCompiler = slotCompiler
    }

    /// Compiles the local wall-clock schedule into Claude's five-field UTC cron format.
    /// A later sync recompiles the plan with the time-zone offset that applies then.
    public func compile(
        schedule: WakeSchedule,
        referenceDate: Date
    ) -> [RoutineSpec] {
        guard schedule.includeClaude else { return [] }

        let offsetMinutes = schedule.timeZone.secondsFromGMT(for: referenceDate) / 60
        let prefix = Self.namePrefix(for: schedule)

        return slotCompiler.slots(for: schedule).map { slot in
            RoutineSpec(
                name: routineName(prefix: prefix, phase: slot.phase),
                cronExpression: cronExpression(
                    slot: slot,
                    offsetMinutes: offsetMinutes
                ),
                enabled: schedule.isEnabled,
                prompt: Self.prompt
            )
        }
    }

    public static func namePrefix(for schedule: WakeSchedule) -> String {
        "Wakebar · \(schedule.id.uuidString.prefix(8).uppercased()) ·"
    }

    private func routineName(prefix: String, phase: ProviderSessionPhase) -> String {
        switch phase {
        case .initial:
            "\(prefix) Morning"
        case let .refresh(index):
            "\(prefix) Refresh \(index)"
        }
    }

    private func cronExpression(
        slot: RecurringSessionSlot,
        offsetMinutes: Int
    ) -> String {
        let minutesPerDay = 24 * 60
        let minutesPerWeek = 7 * minutesPerDay
        var utcWeekdays = Set<Int>()
        var utcHour = 0
        var utcMinute = 0

        for weekday in slot.weekdays {
            let localMinuteOfWeek = ((weekday.rawValue - 1) * minutesPerDay)
                + (slot.hour * 60)
                + slot.minute
            let utcMinuteOfWeek = positiveModulo(
                localMinuteOfWeek - offsetMinutes,
                modulus: minutesPerWeek
            )
            utcWeekdays.insert(utcMinuteOfWeek / minutesPerDay)
            utcHour = (utcMinuteOfWeek % minutesPerDay) / 60
            utcMinute = utcMinuteOfWeek % 60
        }

        let weekdays = utcWeekdays.sorted().map(String.init).joined(separator: ",")
        return "\(utcMinute) \(utcHour) * * \(weekdays)"
    }

    private func positiveModulo(_ value: Int, modulus: Int) -> Int {
        ((value % modulus) + modulus) % modulus
    }
}
