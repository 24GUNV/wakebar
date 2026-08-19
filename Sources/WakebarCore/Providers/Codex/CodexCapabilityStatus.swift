public enum CodexCapabilityStatus: Equatable, Sendable {
    case documented
    case conditional(String)
    case experimental(String)

    public var label: String {
        switch self {
        case .documented:
            "Documented"
        case .conditional:
            "Setup required"
        case .experimental:
            "Experimental"
        }
    }

    public var detail: String? {
        switch self {
        case .documented:
            nil
        case let .conditional(detail), let .experimental(detail):
            detail
        }
    }
}
