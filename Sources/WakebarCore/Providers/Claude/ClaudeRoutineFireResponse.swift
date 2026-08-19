import Foundation

struct ClaudeRoutineFireResponse: Decodable {
    let type: String
    let sessionID: String
    let sessionURL: URL

    enum CodingKeys: String, CodingKey {
        case type
        case sessionID = "claude_code_session_id"
        case sessionURL = "claude_code_session_url"
    }
}
