import Foundation

public struct ProviderSetupPromptCompiler: Sendable {
    private let slotCompiler: RecurringSessionSlotCompiler

    public init(slotCompiler: RecurringSessionSlotCompiler = RecurringSessionSlotCompiler()) {
        self.slotCompiler = slotCompiler
    }

    public func claudeRoutineInstructions(for schedule: WakeSchedule) -> String {
        """
        Name: Wakebar
        Prompt: Reply with exactly "yes".
        Schedule triggers: \(scheduleText(for: schedule))
        Time zone: \(schedule.timeZone.identifier)
        Repositories: None
        Connectors: None
        """
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
