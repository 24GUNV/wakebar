import Foundation

public struct ClaudeRoutineAPIConfiguration: Equatable, Sendable {
    public let fireURL: URL
    public let credential: ClaudeRoutineCredentialReference

    public init(fireURL: URL, credential: ClaudeRoutineCredentialReference) throws {
        guard Self.isAllowed(fireURL) else {
            throw ClaudeRoutineError.invalidEndpoint
        }
        self.fireURL = fireURL
        self.credential = credential
    }

    private static func isAllowed(_ url: URL) -> Bool {
        guard url.scheme == "https",
              url.host == "api.anthropic.com",
              url.user == nil,
              url.password == nil,
              url.query == nil,
              url.fragment == nil
        else {
            return false
        }

        let components = url.path.split(separator: "/")
        guard components.count == 5,
              components[0] == "v1",
              components[1] == "claude_code",
              components[2] == "routines",
              components[3].hasPrefix("trig_"),
              components[3].count > "trig_".count,
              components[4] == "fire"
        else {
            return false
        }

        return true
    }
}
