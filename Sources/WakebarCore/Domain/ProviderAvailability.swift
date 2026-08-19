public enum ProviderAvailability: Equatable, Sendable {
    case notConnected
    case configuredUnverified(String)
    case available
    case unavailable(String)

    public var exceptionalMenuText: String? {
        switch self {
        case .notConnected:
            "Not connected"
        case let .configuredUnverified(detail):
            detail
        case .available:
            nil
        case let .unavailable(reason):
            reason
        }
    }
}
