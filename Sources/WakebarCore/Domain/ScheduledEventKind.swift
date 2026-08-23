public enum ScheduledEventKind: Equatable, Sendable {
    case providerSession(ProviderID, phase: ProviderSessionPhase)

    public var stableKey: String {
        switch self {
        case let .providerSession(provider, phase):
            "session-\(provider.rawValue)-\(phase.stableKey)"
        }
    }
}
