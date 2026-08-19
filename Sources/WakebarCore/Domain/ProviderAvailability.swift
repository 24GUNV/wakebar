public enum ProviderAvailability: Equatable, Sendable {
    case notConnected
    case available
    case unavailable(String)

    public var exceptionalMenuText: String? {
        switch self {
        case .notConnected:
            "Not connected"
        case .available:
            nil
        case let .unavailable(reason):
            reason
        }
    }
}
