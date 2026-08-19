public enum CodexScheduleManager: String, Equatable, Sendable {
    case chatGPT
    case external

    public var detail: String {
        switch self {
        case .chatGPT:
            "Create and manage the schedule in ChatGPT Scheduled."
        case .external:
            "Wakebar or another scheduler must launch the job; Codex CLI does not manage Scheduled tasks."
        }
    }
}
