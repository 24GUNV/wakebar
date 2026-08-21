import Foundation

/// A safe, user-facing reason why a provider did not contribute a live session
/// window. Cases carry no response body or credential material.
enum UsageWindowProviderIssue: Error, Equatable, Sendable {
    case missingCredentials
    case claudeOAuthCredentialMissing
    case keychainUnavailable
    case insufficientScope
    case unauthorized
    case rateLimited
    case network
    case invalidResponse
    case noSessionWindowReported

    var message: String {
        switch self {
        case .missingCredentials:
            "Credentials not found"
        case .claudeOAuthCredentialMissing:
            "Claude OAuth credential unavailable"
        case .keychainUnavailable:
            "Secure credential storage unavailable"
        case .insufficientScope:
            "Token does not include usage access"
        case .unauthorized:
            "Credentials were rejected"
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
