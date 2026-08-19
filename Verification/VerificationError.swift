enum VerificationError: Error {
    case missingUTC
    case invalidFixtureDate
    case invalidFixtureURL
    case unexpectedRefreshes([Int])
    case duplicateFirstClaim
    case ledgerStateMismatch
    case unsafeRetryAllowed
    case unsafeEndpointAccepted
}
