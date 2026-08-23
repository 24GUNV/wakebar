public struct CodexTaskSpec: Codable, Equatable, Sendable {
    public let name: String
    public let schedule: String
    public let timeZoneIdentifier: String
    public let prompt: String
    public let enabled: Bool
    public let weekdays: Set<Weekday>
    public let hour: Int
    public let minute: Int

    public init(
        name: String,
        schedule: String,
        timeZoneIdentifier: String,
        prompt: String,
        enabled: Bool,
        weekdays: Set<Weekday>,
        hour: Int,
        minute: Int
    ) {
        self.name = name
        self.schedule = schedule
        self.timeZoneIdentifier = timeZoneIdentifier
        self.prompt = prompt
        self.enabled = enabled
        self.weekdays = weekdays
        self.hour = hour
        self.minute = minute
    }
}
