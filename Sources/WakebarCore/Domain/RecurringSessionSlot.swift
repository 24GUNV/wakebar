public struct RecurringSessionSlot: Equatable, Sendable {
    public let phase: ProviderSessionPhase
    public let hour: Int
    public let minute: Int
    public let weekdays: Set<Weekday>

    public init(
        phase: ProviderSessionPhase,
        hour: Int,
        minute: Int,
        weekdays: Set<Weekday>
    ) {
        self.phase = phase
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
    }
}
