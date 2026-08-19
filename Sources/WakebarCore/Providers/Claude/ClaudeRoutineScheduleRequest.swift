public struct ClaudeRoutineScheduleRequest: Equatable, Sendable {
    public let name: String
    public let hour: Int
    public let minute: Int
    public let weekdays: Set<Weekday>
    public let timeZoneIdentifier: String
    public let prompt: ClaudeRoutineWakePrompt

    public init(
        name: String,
        hour: Int,
        minute: Int,
        weekdays: Set<Weekday>,
        timeZoneIdentifier: String,
        prompt: ClaudeRoutineWakePrompt = .replyWithYes
    ) {
        self.name = name
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.timeZoneIdentifier = timeZoneIdentifier
        self.prompt = prompt
    }
}
