public struct RoutineSpec: Equatable, Sendable {
    public let name: String
    public let cronExpression: String
    public let enabled: Bool
    public let prompt: String

    public init(
        name: String,
        cronExpression: String,
        enabled: Bool,
        prompt: String
    ) {
        self.name = name
        self.cronExpression = cronExpression
        self.enabled = enabled
        self.prompt = prompt
    }
}
