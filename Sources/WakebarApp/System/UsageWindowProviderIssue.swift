import Foundation
import WakebarCore

/// A safe, user-facing reason why a provider did not contribute a live session
/// window. Cases carry no response body or credential material.
enum UsageWindowProviderIssue: Error, Equatable, Sendable {
    case connectionRequired
    case missingCredentials
    case claudeOAuthCredentialMissing
    case keychainAuthorizationRequired
    case keychainUnavailable
    case insufficientScope
    case unauthorized
    case rateLimited
    case network
    case invalidResponse
    case noSessionWindowReported

    func message(for provider: ProviderID) -> String {
        switch self {
        case .connectionRequired:
            "Connect \(provider == .claude ? "Claude Code" : "Codex") in Wakebar settings"
        case .missingCredentials, .unauthorized:
            provider == .claude
                ? "Sign in again in Claude Code (run `claude`)"
                : "Run `codex login`"
        case .claudeOAuthCredentialMissing:
            "Sign in again in Claude Code (run `claude`)"
        case .keychainAuthorizationRequired:
            "Allow Keychain access when Wakebar next asks"
        case .keychainUnavailable:
            "Secure credential storage unavailable"
        case .insufficientScope:
            "Sign in again in Claude Code (run `claude`)"
        case .rateLimited:
            "Usage service is busy"
        case .network:
            "Usage service unavailable"
        case .invalidResponse:
            "Usage response could not be read"
        case .noSessionWindowReported:
            "No session window reported"
        }
    }
}
