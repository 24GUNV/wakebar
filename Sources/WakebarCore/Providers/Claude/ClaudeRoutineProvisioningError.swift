public enum ClaudeRoutineProvisioningError: Error, Equatable, Sendable {
    case emptyName
    case invalidTime
    case noWeekdays
    case invalidTimeZone
}
