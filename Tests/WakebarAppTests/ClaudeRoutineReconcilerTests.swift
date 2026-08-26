import Foundation
import WakebarCore
import XCTest
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

@MainActor
final class ClaudeRoutineReconcilerTests: XCTestCase {
    func testCreatesUpdatesAndDisablesOnlyPrefixedRoutines() async throws {
        let prefix = "Wakebar · TEST ·"
        let plan = desiredPlan(prefix: prefix)
        let transport = StubClaudeRoutinesTransport(responses: [
            response(profileJSON),
            response(existingRoutineList(prefix: prefix)),
            response(environmentJSON),
            response("{}"),
            response("{}"),
            response("{}"),
        ])
        let reconciler = ClaudeRoutineReconciler(client: makeClient(transport: transport))

        let result = try await reconciler.reconcile(plan: plan, namePrefix: prefix)

        XCTAssertEqual(
            result,
            ClaudeRoutineSyncResult(
                routineCount: 2,
                createdCount: 1,
                updatedCount: 1,
                disabledCount: 1
            )
        )
        let mutationPaths = await transport.requests()
            .filter { $0.httpMethod == "POST" }
            .compactMap { $0.url?.path }
        XCTAssertEqual(mutationPaths, [
            "/v1/code/triggers/managed_morning",
            "/v1/code/triggers",
            "/v1/code/triggers/managed_extra",
        ])
        XCTAssertFalse(mutationPaths.contains { $0.contains("foreign") })
        XCTAssertFalse(mutationPaths.contains { $0.contains("already_disabled") })
    }

    func testMatchingPlanIsIdempotentAndDoesNotResolveEnvironment() async throws {
        let prefix = "Wakebar · TEST ·"
        let plan = desiredPlan(prefix: prefix)
        let transport = StubClaudeRoutinesTransport(responses: [
            response(profileJSON),
            response(syncedRoutineList(prefix: prefix)),
        ])
        let reconciler = ClaudeRoutineReconciler(client: makeClient(transport: transport))

        let result = try await reconciler.reconcile(plan: plan, namePrefix: prefix)

        XCTAssertEqual(result.createdCount, 0)
        XCTAssertEqual(result.updatedCount, 0)
        XCTAssertEqual(result.disabledCount, 0)
        let requests = await transport.requests()
        XCTAssertEqual(requests.map { $0.url?.path }, [
            "/api/oauth/profile",
            "/v1/code/triggers",
        ])
    }

    func testMissingAnthropicCloudEnvironmentHasActionableError() async {
        let prefix = "Wakebar · TEST ·"
        let transport = StubClaudeRoutinesTransport(responses: [
            response(profileJSON),
            response("{\"data\":[]}"),
            response("{\"environments\":[{\"environment_id\":\"pool_one\",\"kind\":\"byoc\"}]}"),
        ])
        let reconciler = ClaudeRoutineReconciler(client: makeClient(transport: transport))

        do {
            _ = try await reconciler.reconcile(
                plan: desiredPlan(prefix: prefix),
                namePrefix: prefix
            )
            XCTFail("Expected a missing cloud environment error")
        } catch {
            XCTAssertEqual(error as? ClaudeRoutinesError, .missingCloudEnvironment)
        }
    }

    func testRetryAfterPartialCreateDoesNotDuplicateTheSuccessfulRoutine() async throws {
        let prefix = "Wakebar · TEST ·"
        let plan = desiredPlan(prefix: prefix)
        let transport = StubClaudeRoutinesTransport(responses: [
            response(profileJSON),
            response("{\"data\":[]}"),
            response(environmentJSON),
            response("{}"),
            response("{}", statusCode: 500),
            response(partialRoutineList(prefix: prefix)),
            response(environmentJSON),
            response("{}"),
        ])
        let reconciler = ClaudeRoutineReconciler(client: makeClient(transport: transport))

        do {
            _ = try await reconciler.reconcile(plan: plan, namePrefix: prefix)
            XCTFail("Expected the second create to fail")
        } catch {
            XCTAssertEqual(error as? ClaudeRoutinesError, .requestFailed(statusCode: 500))
        }

        let retry = try await reconciler.reconcile(plan: plan, namePrefix: prefix)

        XCTAssertEqual(retry.createdCount, 1)
        let createdNames = await transport.requests()
            .filter { $0.httpMethod == "POST" && $0.url?.path == "/v1/code/triggers" }
            .compactMap(\.httpBody)
            .compactMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            .compactMap { $0["name"] as? String }
        XCTAssertEqual(createdNames.filter { $0.hasSuffix("Morning") }.count, 1)
        XCTAssertEqual(createdNames.filter { $0.hasSuffix("Refresh 1") }.count, 2)
    }

    private func desiredPlan(prefix: String) -> [RoutineSpec] {
        [
            RoutineSpec(
                name: "\(prefix) Morning",
                cronExpression: "50 23 * * 0,1,2,3,4",
                enabled: true,
                prompt: "yes"
            ),
            RoutineSpec(
                name: "\(prefix) Refresh 1",
                cronExpression: "50 4 * * 1,2,3,4,5",
                enabled: true,
                prompt: "yes"
            ),
        ]
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

    private func response(_ body: String, statusCode: Int = 200) -> ClaudeRoutinesHTTPResponse {
        ClaudeRoutinesHTTPResponse(data: Data(body.utf8), statusCode: statusCode)
    }

    private var profileJSON: String {
        "{\"organization\":{\"uuid\":\"org_test\"}}"
    }

    private var environmentJSON: String {
        "{\"environments\":[{\"environment_id\":\"env_cloud\",\"kind\":\"anthropic_cloud\"}]}"
    }

    private func existingRoutineList(prefix: String) -> String {
        """
        {"data":[
          {"id":"foreign","name":"Personal routine","cron_expression":"0 9 * * 1","enabled":true,"job_config":{"ccr":{"events":[{"data":{"message":{"content":"leave me alone"}}}]}}},
          {"id":"managed_morning","name":"\(prefix) Morning","cron_expression":"0 0 * * 1","enabled":true,"job_config":{"ccr":{"events":[{"data":{"message":{"content":"old"}}}]}}},
          {"id":"managed_extra","name":"\(prefix) Refresh 9","cron_expression":"0 1 * * 1","enabled":true,"job_config":{"ccr":{"events":[{"data":{"message":{"content":"yes"}}}]}}},
          {"id":"already_disabled","name":"\(prefix) Old","cron_expression":"0 2 * * 1","enabled":false,"job_config":{"ccr":{"events":[{"data":{"message":{"content":"yes"}}}]}}}
        ]}
        """
    }

    private func syncedRoutineList(prefix: String) -> String {
        """
        {"data":[
          {"id":"morning","name":"\(prefix) Morning","cron_expression":"50 23 * * 0,1,2,3,4","enabled":true,"job_config":{"ccr":{"events":[{"data":{"message":{"content":"yes"}}}]}}},
          {"id":"refresh","name":"\(prefix) Refresh 1","cron_expression":"50 4 * * 1,2,3,4,5","enabled":true,"job_config":{"ccr":{"events":[{"data":{"message":{"content":"yes"}}}]}}}
        ]}
        """
    }

    private func partialRoutineList(prefix: String) -> String {
        """
        {"data":[
          {"id":"morning","name":"\(prefix) Morning","cron_expression":"50 23 * * 0,1,2,3,4","enabled":true,"job_config":{"ccr":{"events":[{"data":{"message":{"content":"yes"}}}]}}}
        ]}
        """
    }
}
