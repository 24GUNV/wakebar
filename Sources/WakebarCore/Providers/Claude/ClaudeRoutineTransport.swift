import Foundation

public protocol ClaudeRoutineTransport: Sendable {
    func send(_ request: URLRequest) async throws -> ClaudeRoutineHTTPResponse
}
