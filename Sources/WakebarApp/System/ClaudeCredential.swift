import Foundation

struct ClaudeCredential: Equatable, Sendable {
    let accessToken: String
    let expiresAt: Date?
    let hasRefreshToken: Bool
}
