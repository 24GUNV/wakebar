import Foundation

public struct RoutinePlanCompiler: Sendable {
    public static let prompt = "Reply only with hi. Do not use tools, edit files, publish artifacts, or request permissions."

    private let slotCompiler: RecurringSessionSlotCompiler

    public init(slotCompiler: RecurringSessionSlotCompiler = RecurringSessionSlotCompiler()) {
        self.slotCompiler = slotCompiler
    }

    /// Compiles the local wall-clock schedule into Claude's five-field UTC cron format.
    /// A later sync recompiles the plan with the time-zone offset that applies then.
    ///
    /// - Parameter chainFiresAt: on an "Every reset" schedule, when the next
    ///   chained session should fire, from ``ContinuousChainAnchor``. It adds
    ///   one Routine pinned to that moment. Nil, or any other cadence, adds
    ///   nothing, and a sync then deletes a chain Routine left behind.
    public func compile(
        schedule: WakeSchedule,
        referenceDate: Date,
        chainFiresAt: Date? = nil
    ) -> [RoutineSpec] {
        guard schedule.includeClaude else { return [] }

        let offsetMinutes = schedule.timeZone.secondsFromGMT(for: referenceDate) / 60
        let prefix = Self.namePrefix(for: schedule)

        var plan = slotCompiler.slots(for: schedule).map { slot in
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

        if schedule.cadence == .continuous, let chainFiresAt {
            plan.append(
                RoutineSpec(
                    name: "\(prefix) \(Self.chainRoutineSuffix)",
                    cronExpression: Self.oneShotCronExpression(at: chainFiresAt),
                    enabled: schedule.isEnabled,
                    prompt: Self.prompt
                )
            )
        }

        return plan
    }

    /// Every Routine Wakebar has ever written starts with this, whichever
    /// schedule wrote it. A sync owns them all, so a schedule that was replaced
    /// cannot keep firing under its old prefix.
    public static let familyPrefix = "Wakebar ·"

    public static let chainRoutineSuffix = "Next reset"

    public static func namePrefix(for schedule: WakeSchedule) -> String {
        "\(familyPrefix) \(schedule.id.uuidString.prefix(8).uppercased()) ·"
    }

    /// A cron that names one calendar moment: minute, hour, day and month in
    /// UTC. It repeats only a year later, by which time it has been rewritten
    /// hundreds of times or deleted. Seconds round up so the fire never lands
    /// before the moment it was asked for.
    public static func oneShotCronExpression(at date: Date) -> String {
        let minute: TimeInterval = 60
        let rounded = Date(timeIntervalSince1970: (date.timeIntervalSince1970 / minute).rounded(.up) * minute)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.minute, .hour, .day, .month], from: rounded)
        return "\(parts.minute!) \(parts.hour!) \(parts.day!) \(parts.month!) *"
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
