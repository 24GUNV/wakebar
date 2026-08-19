public enum CodexSchedulingRoute: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case chatGPTWebTask
    case desktopProjectTask
    case localCLI
    case alwaysOnRunner

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .chatGPTWebTask:
            "ChatGPT scheduled task"
        case .desktopProjectTask:
            "Desktop project task"
        case .localCLI:
            "Local Codex CLI"
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
