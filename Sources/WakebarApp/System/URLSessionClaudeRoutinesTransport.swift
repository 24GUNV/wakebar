import Foundation

struct URLSessionClaudeRoutinesTransport: ClaudeRoutinesTransport {
    private let session: URLSession

    init(session: URLSession? = nil) {
        self.session = session ?? Self.makeSession()
    }

    func send(_ request: URLRequest) async throws -> ClaudeRoutinesHTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw ClaudeRoutinesError.invalidResponse
        }
        return ClaudeRoutinesHTTPResponse(data: data, statusCode: response.statusCode)
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 20
        return URLSession(configuration: configuration)
    }
}
