public enum ProviderSessionPhase: Equatable, Sendable {
    case initial
    case refresh(index: Int)

    public var stableKey: String {
        switch self {
        case .initial:
            "initial"
        case let .refresh(index):
            "refresh-\(index)"
        }
    }
}
