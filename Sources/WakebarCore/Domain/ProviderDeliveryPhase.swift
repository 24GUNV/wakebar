public enum ProviderDeliveryPhase: String, Codable, Equatable, Sendable {
    case draft
    case awaitingConfirmation
    case confirmed
    case failed

    public var displayName: String {
        switch self {
        case .draft:
            "Draft"
        case .awaitingConfirmation:
            "Awaiting confirmation"
        case .confirmed:
            "Confirmed by you"
        case .failed:
            "Setup failed"
        }
    }
}
