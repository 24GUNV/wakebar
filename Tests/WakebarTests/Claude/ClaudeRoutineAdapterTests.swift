import Foundation
import XCTest
@testable import WakebarCore

final class ClaudeRoutineAdapterTests: XCTestCase {
    func testConfigurationRejectsCredentialExfiltrationEndpoint() throws {
        let endpoint = try XCTUnwrap(
            URL(string: "https://example.com/v1/claude_code/routines/trig_123/fire")
        )

        XCTAssertThrowsError(
            try ClaudeRoutineAPIConfiguration(
                fireURL: endpoint,
                credential: ClaudeRoutineCredentialReference(id: "claude.test")
            )
        ) { error in
            XCTAssertEqual(error as? ClaudeRoutineError, .invalidEndpoint)
        }
    }

    func testFireUsesOnlyAnthropicRoutineHeadersAndDecodesSession() async throws {
        let response = """
        {
          "type": "routine_fire",
          "claude_code_session_id": "session_123",
          "claude_code_session_url": "https://claude.ai/code/session_123"
        }
        """
        let transport = RecordingClaudeRoutineTransport(
            response: ClaudeRoutineHTTPResponse(
                data: try XCTUnwrap(response.data(using: .utf8)),
                statusCode: 200
            )
        )
        let adapter = try makeAdapter(transport: transport)
        let trigger = TriggerRequest(
            scheduleID: UUID(),
            plannedFireDate: .now,
            prompt: "hi"
        )

        let result = try await adapter.fire(trigger)
        let lastRequest = await transport.lastRequest
        let request = try XCTUnwrap(lastRequest)

        XCTAssertEqual(request.url?.host, "api.anthropic.com")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-ant-oat01-test-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "experimental-cc-routine-2026-04-01")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertEqual(result.sessionID, "session_123")
        XCTAssertEqual(result.sessionURL.host, "claude.ai")
    }

    func testProbeDoesNotFireRoutine() async throws {
        let transport = RecordingClaudeRoutineTransport(
            response: ClaudeRoutineHTTPResponse(data: Data(), statusCode: 500)
        )
        let adapter = try makeAdapter(transport: transport)

        let snapshot = await adapter.probe()
        let lastRequest = await transport.lastRequest

        XCTAssertEqual(snapshot.availability, .configuredUnverified("Token stored; API not verified"))
        XCTAssertNil(lastRequest)
    }

    func testFireMapsUsageLimitWithoutRetrying() async throws {
        let transport = RecordingClaudeRoutineTransport(
            response: ClaudeRoutineHTTPResponse(
                data: Data(),
                statusCode: 429,
                retryAfter: "3600"
            )
        )
        let adapter = try makeAdapter(transport: transport)
        let trigger = TriggerRequest(
            scheduleID: UUID(),
            plannedFireDate: .now,
            prompt: "hi"
        )

        do {
            try await adapter.fire(trigger)
            XCTFail("Expected the usage-limit error")
        } catch {
            XCTAssertEqual(error as? ClaudeRoutineError, .usageLimitReached(retryAfter: "3600"))
        }
        let sendCount = await transport.sendCount
        XCTAssertEqual(sendCount, 1)
    }

    func testTriggerRecordsSessionCreationWithoutClaimingPromptCompletion() async throws {
        let response = """
        {
          "type": "routine_fire",
          "claude_code_session_id": "session_456",
          "claude_code_session_url": "https://claude.ai/code/session_456"
        }
        """
        let transport = RecordingClaudeRoutineTransport(
            response: ClaudeRoutineHTTPResponse(
                data: try XCTUnwrap(response.data(using: .utf8)),
                statusCode: 200
            )
        )
        let adapter = try makeAdapter(transport: transport)
        let trigger = TriggerRequest(scheduleID: UUID(), plannedFireDate: .now, prompt: "hi")

        let receipt = try await adapter.trigger(trigger)

        XCTAssertEqual(receipt.outcome, .sessionCreated)
        XCTAssertEqual(receipt.externalID, "session_456")
        XCTAssertEqual(receipt.externalURL?.host, "claude.ai")
    }

    private func makeAdapter(
        transport: RecordingClaudeRoutineTransport
    ) throws -> ClaudeRoutineAdapter<FixedClaudeRoutineCredentialStore, RecordingClaudeRoutineTransport> {
        let endpoint = try XCTUnwrap(
            URL(string: "https://api.anthropic.com/v1/claude_code/routines/trig_123/fire")
        )
        let configuration = try ClaudeRoutineAPIConfiguration(
            fireURL: endpoint,
            credential: ClaudeRoutineCredentialReference(id: "claude.test")
        )
        return ClaudeRoutineAdapter(
            configuration: configuration,
            credentialStore: FixedClaudeRoutineCredentialStore(token: "sk-ant-oat01-test-token"),
            transport: transport
        )
    }
}

private struct FixedClaudeRoutineCredentialStore: ClaudeRoutineCredentialStore {
    let token: String?

    func bearerToken(for reference: ClaudeRoutineCredentialReference) async throws -> String? {
        _ = reference
        return token
    }
}

private actor RecordingClaudeRoutineTransport: ClaudeRoutineTransport {
    let response: ClaudeRoutineHTTPResponse
    private(set) var lastRequest: URLRequest?
    private(set) var sendCount = 0

    init(response: ClaudeRoutineHTTPResponse) {
        self.response = response
    }

    func send(_ request: URLRequest) async throws -> ClaudeRoutineHTTPResponse {
        lastRequest = request
        sendCount += 1
        return response
    }
}
