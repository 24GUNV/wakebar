import Foundation
import WakebarCore
import XCTest
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

@MainActor
final class ClaudeRoutinesClientTests: XCTestCase {
    func testUsesTeleportOrganizationHeadersAndAllRoutineEndpoints() async throws {
        let transport = StubClaudeRoutinesTransport(responses: [
            response(profileJSON),
            response(routineListJSON),
            response(wrappedRoutineJSON),
            response("{}"),
            response("{}"),
            response("{}"),
            response(environmentJSON),
        ])
        let client = makeClient(transport: transport)
        let spec = RoutineSpec(
            name: "Wakebar · TEST · Morning",
            cronExpression: "50 23 * * 0,1,2,3,4",
            enabled: true,
            prompt: "yes"
        )

        let routines = try await client.listRoutines(credentialIntent: .userInitiated)
        let routine = try await client.routine(
            id: "trigger_one",
            credentialIntent: .userInitiated
        )
        try await client.createRoutine(
            spec,
            environmentID: "env_cloud",
            credentialIntent: .userInitiated
        )
        try await client.updateRoutine(
            id: "trigger_one",
            spec: spec,
            environmentID: "env_cloud",
            credentialIntent: .userInitiated
        )
        try await client.runRoutine(
            id: "trigger_one",
            credentialIntent: .userInitiated
        )
        let environments = try await client.environments(credentialIntent: .userInitiated)

        XCTAssertEqual(routines.first?.prompt, "yes")
        XCTAssertEqual(routine.id, "trigger_one")
        XCTAssertEqual(environments, [ClaudeEnvironment(id: "env_cloud", kind: "anthropic_cloud")])

        let requests = await transport.requests()
        XCTAssertEqual(requests.map { $0.url?.path }, [
            "/api/oauth/profile",
            "/v1/code/triggers",
            "/v1/code/triggers/trigger_one",
            "/v1/code/triggers",
            "/v1/code/triggers/trigger_one",
            "/v1/code/triggers/trigger_one/run",
            "/v1/environment_providers",
        ])
        XCTAssertEqual(requests.map(\.httpMethod), ["GET", "GET", "GET", "POST", "POST", "POST", "GET"])

        for request in requests.dropFirst() {
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer oauth-test-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-organization-uuid"), "org_test")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        }
        for request in requests[1...5] {
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "anthropic-beta"),
                "ccr-triggers-2026-01-30"
            )
        }
        XCTAssertNil(requests.last?.value(forHTTPHeaderField: "anthropic-beta"))

        let createBody = try XCTUnwrap(requests[3].httpBody)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: createBody) as? [String: Any]
        )
        let jobConfig = try XCTUnwrap(object["job_config"] as? [String: Any])
        let ccr = try XCTUnwrap(jobConfig["ccr"] as? [String: Any])
        let sessionContext = try XCTUnwrap(ccr["session_context"] as? [String: Any])
        XCTAssertEqual(sessionContext["model"] as? String, "claude-sonnet-5")
        XCTAssertEqual(sessionContext["allowed_tools"] as? [String], [])
        XCTAssertNil(sessionContext["sources"])

        let events = try XCTUnwrap(ccr["events"] as? [[String: Any]])
        let data = try XCTUnwrap(events.first?["data"] as? [String: Any])
        let uuid = try XCTUnwrap(data["uuid"] as? String)
        XCTAssertEqual(uuid, uuid.lowercased())
        XCTAssertNotNil(UUID(uuidString: uuid))
        XCTAssertTrue(data["parent_tool_use_id"] is NSNull)
        let message = try XCTUnwrap(data["message"] as? [String: Any])
        XCTAssertEqual(message["content"] as? String, "yes")
    }

    func testNotFoundIsReportedAsAPIChanged() async {
        let transport = StubClaudeRoutinesTransport(responses: [
            response(profileJSON),
            response("{}", statusCode: 404),
        ])
        let client = makeClient(transport: transport)

        do {
            _ = try await client.listRoutines(credentialIntent: .userInitiated)
            XCTFail("Expected the undocumented API change error")
        } catch {
            XCTAssertEqual(error as? ClaudeRoutinesError, .apiChanged)
        }
    }

    func testRejectedBetaIsReportedAsAPIChanged() async {
        let transport = StubClaudeRoutinesTransport(responses: [
            response(profileJSON),
            response("{\"error\":\"unknown beta ccr-triggers\"}", statusCode: 400),
        ])
        let client = makeClient(transport: transport)

        do {
            _ = try await client.listRoutines(credentialIntent: .userInitiated)
            XCTFail("Expected the beta rejection error")
        } catch {
            XCTAssertEqual(error as? ClaudeRoutinesError, .apiChanged)
        }
    }

    func testMissingCredentialIsReportedBeforeTransportRuns() async {
        let transport = StubClaudeRoutinesTransport(responses: [])
        let resolver = UsageWindowCredentialResolver(
            environment: [:],
            homeDirectory: URL(filePath: "/nonexistent-wakebar-test-home"),
            keychainLookup: { _ in .notFound }
        )
        let client = ClaudeRoutinesClient(
            credentialStore: ClaudeCredentialStore(resolver: resolver),
            transport: transport
        )

        do {
            _ = try await client.listRoutines(credentialIntent: .userInitiated)
            XCTFail("Expected the authentication error")
        } catch {
            XCTAssertEqual(error as? ClaudeRoutinesError, .noAuthentication)
        }
        let requests = await transport.requests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testBackgroundRequestNeverAllowsCredentialUI() async throws {
        let transport = StubClaudeRoutinesTransport(responses: [
            response(profileJSON),
            response(routineListJSON),
        ])
        let keychain = StubKeychainLookup(
            result: .data(
                Data(
                    "{\"claudeAiOauth\":{\"accessToken\":\"oauth-test-token\"}}".utf8
                )
            )
        )
        let resolver = UsageWindowCredentialResolver(
            environment: [:],
            homeDirectory: URL(filePath: "/nonexistent-wakebar-test-home"),
            keychainLookup: { allowUI in keychain.lookup(allowUI: allowUI) }
        )
        let client = ClaudeRoutinesClient(
            credentialStore: ClaudeCredentialStore(resolver: resolver),
            transport: transport
        )

        _ = try await client.listRoutines(credentialIntent: .background)

        XCTAssertEqual(keychain.allowUIArguments, [false])
    }

    func testTransportFailureIsReportedAsNetworkError() async {
        let transport = StubClaudeRoutinesTransport(responses: [])
        let client = makeClient(transport: transport)

        do {
            _ = try await client.listRoutines(credentialIntent: .userInitiated)
            XCTFail("Expected the network error")
        } catch {
            XCTAssertEqual(error as? ClaudeRoutinesError, .network)
        }
    }

    private func makeClient(transport: StubClaudeRoutinesTransport) -> ClaudeRoutinesClient {
        let credentials = Data(
            "{\"claudeAiOauth\":{\"accessToken\":\"oauth-test-token\"}}".utf8
        )
        let resolver = UsageWindowCredentialResolver(
            environment: [:],
            homeDirectory: URL(filePath: "/nonexistent-wakebar-test-home"),
            keychainLookup: { _ in .data(credentials) }
        )
        return ClaudeRoutinesClient(
            credentialStore: ClaudeCredentialStore(resolver: resolver),
            transport: transport
        )
    }

    private func response(
        _ body: String,
        statusCode: Int = 200
    ) -> ClaudeRoutinesHTTPResponse {
        ClaudeRoutinesHTTPResponse(data: Data(body.utf8), statusCode: statusCode)
    }

    private var profileJSON: String {
        "{\"organization\":{\"uuid\":\"org_test\"}}"
    }

    private var environmentJSON: String {
        "{\"environments\":[{\"environment_id\":\"env_cloud\",\"kind\":\"anthropic_cloud\"}]}"
    }

    private var routineListJSON: String {
        "{\"data\":[\(routineJSON)]}"
    }

    private var wrappedRoutineJSON: String {
        "{\"trigger\":\(routineJSON)}"
    }

    private var routineJSON: String {
        """
        {"id":"trigger_one","name":"Wakebar · TEST · Morning","cron_expression":"50 23 * * 0,1,2,3,4","enabled":true,"job_config":{"ccr":{"events":[{"data":{"message":{"content":"yes"}}}]}}}
        """
    }
}
