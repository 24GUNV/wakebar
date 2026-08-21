public struct ClaudeRoutineCLISetupPlan: Equatable, Sendable {
    public static let minimumVersion = ClaudeCLIVersion(major: 2, minor: 1, patch: 227)

    public let command: String

    public init(schedule: WakeSchedule) {
        command = ProviderSetupPromptCompiler().claudeRoutineCLICommand(for: schedule)
    }
}
