import Foundation
import WakebarCore
import XCTest
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

@MainActor
final class ClaudeSetupModelTests: XCTestCase {
    func testBackgroundSyncKeepsCredentialIntentQuietThroughReconciliation() async throws {
        let keychain = StubKeychainLookup(
            result: .data(
                Data(
                    "{\"claudeAiOauth\":{\"accessToken\":\"oauth-test-token\"}}".utf8
                )
            )
        )
        let resolver = UsageWindowCredentialResolver(
            accessAllowed: { _ in true },
            environment: [:],
            homeDirectory: URL(filePath: "/nonexistent-wakebar-test-home"),
            keychainLookup: { allowUI in keychain.lookup(allowUI: allowUI) }
        )
        let credentialStore = ClaudeCredentialStore(resolver: resolver)
        let service = StubClaudeRoutinesService()
        let model = ClaudeSetupModel(
            reconciler: ClaudeRoutineReconciler(client: service),
            credentialStore: credentialStore
        )

        _ = await model.sync(
            for: .default,
            credentialIntent: .background
        )

        let credentialIntents = await service.credentialIntents
        XCTAssertEqual(keychain.allowUIArguments, [false])
        XCTAssertFalse(credentialIntents.isEmpty)
        XCTAssertTrue(credentialIntents.allSatisfy { $0 == .background })
    }

    /// A sync owns every Wakebar Routine, so one left enabled by a schedule
    /// that no longer exists is deleted alongside the current plan.
    func testSyncDeletesRoutinesLeftByAnEarlierScheduleAndWritesTheChainRoutine() async throws {
        let keychain = StubKeychainLookup(
            result: .data(
                Data(
                    "{\"claudeAiOauth\":{\"accessToken\":\"oauth-test-token\"}}".utf8
                )
            )
        )
        let resolver = UsageWindowCredentialResolver(
            accessAllowed: { _ in true },
            environment: [:],
            homeDirectory: URL(filePath: "/nonexistent-wakebar-test-home"),
            keychainLookup: { allowUI in keychain.lookup(allowUI: allowUI) }
        )
        var schedule = WakeSchedule.default
        schedule.isEnabled = true
        schedule.cadence = .continuous
        let service = StubClaudeRoutinesService(routines: [
            ClaudeRoutine(
                id: "earlier",
                name: "Wakebar · OLD1 · Morning",
                cronExpression: "50 23 * * 0,1,2,3,4",
                enabled: true,
                prompt: RoutinePlanCompiler.prompt
            ),
            ClaudeRoutine(
                id: "personal",
                name: "Personal routine",
                cronExpression: "0 9 * * 1",
                enabled: true,
                prompt: "leave me alone"
            ),
        ])
        let model = ClaudeSetupModel(
            reconciler: ClaudeRoutineReconciler(client: service),
            credentialStore: ClaudeCredentialStore(resolver: resolver)
        )
        let chainFiresAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-05T21:53:00Z"))

        let result = await model.sync(
            for: schedule,
            credentialIntent: .background,
            chainFiresAt: chainFiresAt
        )

        XCTAssertEqual(result?.deletedCount, 1)
        XCTAssertEqual(result?.createdCount, 2)
        let deletedIDs = await service.deletedIDs
        XCTAssertEqual(deletedIDs, ["earlier"])
        let created = await service.createdSpecs
        XCTAssertEqual(
            created.map(\.name),
            [
                "\(RoutinePlanCompiler.namePrefix(for: schedule)) Morning",
                "\(RoutinePlanCompiler.namePrefix(for: schedule)) Next reset",
            ]
        )
        XCTAssertEqual(created.last?.cronExpression, "53 21 5 9 *")
    }

    func testBackgroundAuthorizationFailureHasActionableMessage() async {
        let keychain = StubKeychainLookup(result: .interactionRequired)
        let resolver = UsageWindowCredentialResolver(
            accessAllowed: { _ in true },
            environment: [:],
            homeDirectory: URL(filePath: "/nonexistent-wakebar-test-home"),
            keychainLookup: { allowUI in keychain.lookup(allowUI: allowUI) }
        )
        let model = ClaudeSetupModel(
            credentialStore: ClaudeCredentialStore(resolver: resolver)
        )

        let result = await model.sync(
            for: .default,
            credentialIntent: .background
        )

        XCTAssertNil(result)
        XCTAssertEqual(
            model.failureMessage,
            "Allow Keychain access when Wakebar next asks"
        )
        XCTAssertEqual(keychain.allowUIArguments, [false])
    }
}
