public enum ExecutionBackend: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case providerCloud
    case thisMac
    case alwaysOnRunner

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .providerCloud:
            "Provider cloud"
        case .thisMac:
            "This Mac"
        case .alwaysOnRunner:
            "Always-on runner"
        }
    }

    public func statusText(for provider: ProviderID) -> String {
        switch self {
        case .providerCloud:
            if provider == .claude {
                "Provider cloud not configured"
            } else {
                "Provider scheduling not verified"
            }
        case .thisMac:
            "Local runner not configured"
        case .alwaysOnRunner:
            "Always-on runner not connected"
        }
    }
}
