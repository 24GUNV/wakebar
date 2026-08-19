public struct RecurringSessionSlotCompiler: Sendable {
    public init() {}

    public func slots(for schedule: WakeSchedule) -> [RecurringSessionSlot] {
        guard schedule.isValid else { return [] }

        let wakeMinutes = (schedule.hour * 60) + schedule.minute
        let firstSessionMinutes = wakeMinutes - schedule.sessionLeadMinutes
        let initial = makeSlot(
            phase: .initial,
            totalMinutes: firstSessionMinutes,
            wakeWeekdays: schedule.selectedWeekdays
        )

        guard schedule.repeatEveryFiveHours else { return [initial] }

        let cutoffMinutes = schedule.repeatUntilHour * 60
        var slots = [initial]
        var candidateMinutes = firstSessionMinutes + (5 * 60)
        var refreshIndex = 1

        while candidateMinutes <= cutoffMinutes {
            slots.append(
                makeSlot(
                    phase: .refresh(index: refreshIndex),
                    totalMinutes: candidateMinutes,
                    wakeWeekdays: schedule.selectedWeekdays
                )
            )
            candidateMinutes += 5 * 60
            refreshIndex += 1
        }

        return slots
    }

    private func makeSlot(
        phase: ProviderSessionPhase,
        totalMinutes: Int,
        wakeWeekdays: Set<Weekday>
    ) -> RecurringSessionSlot {
        let dayOffset = floorDivision(totalMinutes, by: 24 * 60)
        let normalizedMinutes = positiveModulo(totalMinutes, modulus: 24 * 60)
        return RecurringSessionSlot(
            phase: phase,
            hour: normalizedMinutes / 60,
            minute: normalizedMinutes % 60,
            weekdays: shifted(wakeWeekdays, by: dayOffset)
        )
    }

    private func shifted(_ weekdays: Set<Weekday>, by offset: Int) -> Set<Weekday> {
        Set(weekdays.compactMap { weekday in
            let zeroBased = positiveModulo((weekday.rawValue - 1) + offset, modulus: 7)
            return Weekday(rawValue: zeroBased + 1)
        })
    }

    private func positiveModulo(_ value: Int, modulus: Int) -> Int {
        ((value % modulus) + modulus) % modulus
    }

    private func floorDivision(_ value: Int, by divisor: Int) -> Int {
        let quotient = value / divisor
        let remainder = value % divisor
        return remainder < 0 ? quotient - 1 : quotient
    }
}
