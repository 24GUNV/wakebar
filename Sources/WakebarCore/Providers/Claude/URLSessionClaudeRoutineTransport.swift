import Foundation

public struct URLSessionClaudeRoutineTransport: ClaudeRoutineTransport {
    public init() {}

    public func send(_ request: URLRequest) async throws -> ClaudeRoutineHTTPResponse {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ClaudeRoutineError.invalidResponse
        }

        return ClaudeRoutineHTTPResponse(
            data: data,
            statusCode: response.statusCode,
            retryAfter: response.value(forHTTPHeaderField: "Retry-After")
        )
    }
}
