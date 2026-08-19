public enum ScheduledEventKind: Equatable, Sendable {
    case providerSession(ProviderID, phase: ProviderSessionPhase)
    case phoneAlarm

    public var stableKey: String {
        switch self {
        case let .providerSession(provider, phase):
            "session-\(provider.rawValue)-\(phase.stableKey)"
        case .phoneAlarm:
            "phone-alarm"
        }
    }
}
