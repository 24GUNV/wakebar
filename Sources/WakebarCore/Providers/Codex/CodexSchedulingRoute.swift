public enum CodexSchedulingRoute: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    /// Retained only so existing saved schedules decode. Do not remove.
    case chatGPTWebTask
    /// Retained only so existing saved schedules decode. Do not remove.
    case desktopProjectTask
    case localCLI
    /// Retained only so existing saved schedules decode. Do not remove.
    case alwaysOnRunner

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .chatGPTWebTask:
            "ChatGPT scheduled task"
        case .desktopProjectTask:
            "Desktop project task"
        case .localCLI:
            "This Mac"
        case .alwaysOnRunner:
            "Always-on runner"
        }
    }

    public var executionBackend: ExecutionBackend {
        switch self {
        case .chatGPTWebTask:
            .providerCloud
        case .desktopProjectTask, .localCLI:
            .thisMac
        case .alwaysOnRunner:
            .alwaysOnRunner
        }
    }
}
