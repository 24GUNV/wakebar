public struct ClaudeRoutineScheduleCompiler: Sendable {
    private let slotCompiler: RecurringSessionSlotCompiler
    private let provisioner: ClaudeRoutineProvisioner

    public init(
        slotCompiler: RecurringSessionSlotCompiler = RecurringSessionSlotCompiler(),
        provisioner: ClaudeRoutineProvisioner = ClaudeRoutineProvisioner()
    ) {
        self.slotCompiler = slotCompiler
        self.provisioner = provisioner
    }

    public func plans(for schedule: WakeSchedule) throws -> [ClaudeRoutineProvisioningPlan] {
        try slotCompiler.slots(for: schedule).map { slot in
            try provisioner.makePlan(
                for: ClaudeRoutineScheduleRequest(
                    name: routineName(for: slot.phase),
                    hour: slot.hour,
                    minute: slot.minute,
                    weekdays: slot.weekdays,
                    timeZoneIdentifier: schedule.timeZone.identifier,
                    prompt: .sayHi
                )
            )
        }
    }

    private func routineName(for phase: ProviderSessionPhase) -> String {
        switch phase {
        case .initial:
            "Wakebar · Morning session"
        case let .refresh(index):
            "Wakebar · Refresh \(index)"
        }
    }
}
