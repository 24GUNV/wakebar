import Foundation

public struct ClaudeRoutineFireResult: Equatable, Sendable {
    public let sessionID: String
    public let sessionURL: URL

    public init(sessionID: String, sessionURL: URL) {
        self.sessionID = sessionID
        self.sessionURL = sessionURL
    }
}
