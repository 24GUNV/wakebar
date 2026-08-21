import Foundation

public struct ProviderSetupPromptCompiler: Sendable {
    private let slotCompiler: RecurringSessionSlotCompiler

    public init(slotCompiler: RecurringSessionSlotCompiler = RecurringSessionSlotCompiler()) {
        self.slotCompiler = slotCompiler
    }

    public func claudeRoutineInstructions(for schedule: WakeSchedule) -> String {
        return """
        Name: Wakebar
        Prompt: Reply with exactly "yes".
        Schedule triggers: \(scheduleText(for: schedule))
        Time zone: \(schedule.timeZone.identifier)
        Repositories: None
        Connectors: None
        """
    }

    public func claudeRoutineCLICommand(for schedule: WakeSchedule) -> String {
        let prefix = claudeRoutinePrefix(for: schedule)
        let desiredRoutines = slotCompiler.slots(for: schedule).enumerated().map { index, slot in
            let phaseName = switch slot.phase {
            case .initial:
                "Morning"
            case let .refresh(refreshIndex):
                "Refresh \(refreshIndex)"
            }
            return """
            \(index + 1). "\(prefix) \(phaseName)"
               Run at \(twoDigit(slot.hour)):\(twoDigit(slot.minute)) on \(weekdayNames(slot.weekdays)) in \(schedule.timeZone.identifier).
            """
        }.joined(separator: "\n")

        return """
        /schedule Reconcile only cloud Routines whose names begin with "\(prefix)".

        Desired Routines:
        \(desiredRoutines)

        For every Routine, use the Default cloud environment, no repositories, no connectors, and this exact saved prompt: Reply with exactly "yes". Do not inspect repositories, call connectors, run commands, or modify files.

        First list existing matching Routines. Show one combined before-and-after review and ask for one confirmation. Then update matching Routines, create missing ones, and disable obsolete matching Routines. Do not modify any other Routine. Return the resulting Routine links.
        """
    }

    public func claudeRoutinePrefix(for schedule: WakeSchedule) -> String {
        "Wakebar · \(schedule.id.uuidString.prefix(8).uppercased()) ·"
    }

    public func chatGPTTaskPrompt(for schedule: WakeSchedule) -> String {
        """
        Create a standalone recurring ChatGPT Scheduled task named "Wakebar" that runs at \(scheduleText(for: schedule)), using the \(schedule.timeZone.identifier) time zone. At each run, reply with exactly "hi". Show me the final schedule for confirmation before saving it.
        """
    }

    private func scheduleText(for schedule: WakeSchedule) -> String {
        slotCompiler.slots(for: schedule).map { slot in
            "\(twoDigit(slot.hour)):\(twoDigit(slot.minute)) on \(weekdayNames(slot.weekdays))"
        }.joined(separator: "; ")
    }

    private func twoDigit(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private func weekdayNames(_ weekdays: Set<Weekday>) -> String {
        Weekday.displayOrder
            .filter(weekdays.contains)
            .map(\.fullLabel)
            .formatted()
    }
}
