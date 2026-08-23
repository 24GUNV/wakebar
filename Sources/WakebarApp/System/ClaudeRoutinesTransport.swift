import Foundation

protocol ClaudeRoutinesTransport: Sendable {
    func send(_ request: URLRequest) async throws -> ClaudeRoutinesHTTPResponse
}
