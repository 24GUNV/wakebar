public enum ProviderID: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case claude
    case codex

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .claude:
            "Claude Code"
        case .codex:
            "Codex"
        }
    }

    public var minimalPrompt: String { "hi" }

    public var hostedPromptDescription: String {
        switch self {
        case .claude:
            "requests a tool-free “hi” reply"
        case .codex:
            "sends “hi”"
        }
    }
}
