public enum CodexCLIAvailability: Equatable, Sendable {
    case notChecked
    case notFound
    case available(version: String?)

    public var isAvailable: Bool {
        if case .available = self {
            true
        } else {
            false
        }
    }
}
