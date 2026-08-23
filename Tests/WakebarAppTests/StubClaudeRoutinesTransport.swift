import Foundation
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

actor StubClaudeRoutinesTransport: ClaudeRoutinesTransport {
    private var responses: [ClaudeRoutinesHTTPResponse]
    private var recordedRequests: [URLRequest] = []

    init(responses: [ClaudeRoutinesHTTPResponse]) {
        self.responses = responses
    }

    func send(_ request: URLRequest) async throws -> ClaudeRoutinesHTTPResponse {
        recordedRequests.append(request)
        guard !responses.isEmpty else {
            throw ClaudeRoutinesError.network
        }
        return responses.removeFirst()
    }

    func requests() -> [URLRequest] {
        recordedRequests
    }
}
