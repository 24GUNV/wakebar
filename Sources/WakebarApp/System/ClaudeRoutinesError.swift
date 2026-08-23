import Foundation

enum ClaudeRoutinesError: Error, Equatable, LocalizedError, Sendable {
    case noAuthentication
    case apiChanged
    case network
    case missingCloudEnvironment
    case missingMorningRoutine
    case accessDenied
    case rateLimited
    case invalidResponse
    case requestFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .noAuthentication:
            "Sign in again in Claude Code (run `claude`)"
        case .apiChanged:
            "Claude's undocumented Routines API changed. Update Wakebar before syncing again."
        case .network:
            "Wakebar could not reach Claude. Check the network and try again."
        case .missingCloudEnvironment:
            "Open https://claude.ai/code once to create a Claude cloud environment, then try again."
        case .missingMorningRoutine:
            "Wakebar could not find or create the managed Morning Routine."
        case .accessDenied:
            "This Claude.ai account cannot manage Claude Code Routines."
        case .rateLimited:
            "Claude is limiting Routine requests. Try again later."
        case .invalidResponse:
            "Claude returned an unexpected Routines response."
        case let .requestFailed(statusCode):
            "Claude could not sync Routines (HTTP \(statusCode))."
        }
    }
}
