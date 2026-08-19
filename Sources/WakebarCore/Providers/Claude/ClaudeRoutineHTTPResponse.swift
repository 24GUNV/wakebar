import Foundation

public struct ClaudeRoutineHTTPResponse: Sendable {
    public let data: Data
    public let statusCode: Int
    public let retryAfter: String?

    public init(data: Data, statusCode: Int, retryAfter: String? = nil) {
        self.data = data
        self.statusCode = statusCode
        self.retryAfter = retryAfter
    }
}
