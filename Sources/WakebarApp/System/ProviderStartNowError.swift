enum ProviderStartNowError: Error, Equatable, Sendable {
    case unavailable
    case clipboardUnavailable
    case browserUnavailable
}
