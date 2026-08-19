public enum CodexHostRequirement: Equatable, Sendable {
    case openAIHosted
    case thisMac(appMustBeRunning: Bool)
    case externalRunner

    public var canRunWhileThisMacIsOff: Bool {
        switch self {
        case .openAIHosted, .externalRunner:
            true
        case .thisMac:
            false
        }
    }

    public var detail: String {
        switch self {
        case .openAIHosted:
            "Runs as a hosted task and cannot work directly in a folder on this Mac."
        case let .thisMac(appMustBeRunning):
            if appMustBeRunning {
                "This Mac must be on, the ChatGPT desktop app must be running, and the project must remain available."
            } else {
                "This Mac must be on when the external scheduler starts Codex."
            }
        case .externalRunner:
            "The runner must be on and retain valid Codex authentication. This Mac can be off."
        }
    }
}
