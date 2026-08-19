import Foundation

public enum ClaudeRoutineError: Error, Equatable, Sendable {
    case invalidEndpoint
    case missingCredential
    case invalidCredential
    case promptTooLong
    case routinePausedOrInvalid
    case accessDenied
    case routineNotFound
    case usageLimitReached(retryAfter: String?)
    case serviceUnavailable
    case requestFailed(statusCode: Int)
    case invalidResponse

    public var userMessage: String {
        switch self {
        case .invalidEndpoint:
            "Use the Routine fire URL copied from Claude."
        case .missingCredential:
            "Add the Routine token to this Mac."
        case .invalidCredential:
            "The Routine token is not valid. Generate a new token in Claude."
        case .promptTooLong:
            "The prompt exceeds Claude's 65,536-character limit."
        case .routinePausedOrInvalid:
            "Claude rejected the request. Check whether the Routine is paused."
        case .accessDenied:
            "This Claude account cannot run the Routine through the API."
        case .routineNotFound:
            "Claude could not find this Routine."
        case let .usageLimitReached(retryAfter):
            if let retryAfter {
                "Claude's Routine limit is reached. Try again after \(retryAfter)."
            } else {
                "Claude's Routine or subscription limit is reached."
            }
        case .serviceUnavailable:
            "Claude Routines are temporarily unavailable."
        case .requestFailed:
            "Claude could not start the Routine."
        case .invalidResponse:
            "Claude returned an unexpected response."
        }
    }
}
