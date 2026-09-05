import Foundation
import WakebarCore
import XCTest
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

@MainActor
final class LiveProviderAcceptanceTests: XCTestCase {
    func testCodexUsageReadsTheSignedInAccount() async throws {
        try requireLiveTests()

        let windows = try await CodexUsageAPIClient().currentWindows(now: .now)

        XCTAssertFalse(windows.isEmpty, "Codex returned no usage windows.")
        XCTAssertTrue(windows.allSatisfy { $0.provider == .codex })
        XCTAssertTrue(windows.contains { $0.limitKind == .weekly })
    }

    /// A background read must come back without a Keychain dialog. This test
    /// cannot see the dialog, but a run that hangs on one or that throws
    /// `keychainAuthorizationRequired` is the failure it is here to catch;
    /// `log show --predicate 'process == "securityd"'` after a run shows
    /// whether a prompt was displayed for xctest.
    func testClaudeUsageReadsQuietlyInTheBackground() async throws {
        try requireLiveTests()
        let now = Date.now

        let credential = try UsageWindowCredentialResolver().claudeCredential(allowUI: false)
        let windows = try await ClaudeUsageAPIClient(credentialIntent: .background)
            .currentWindows(now: now)

        XCTAssertFalse(credential.accessToken.isEmpty)
        XCTAssertFalse(windows.isEmpty, "Claude returned no usage windows.")
        XCTAssertTrue(windows.allSatisfy { $0.provider == .claude })
        for window in windows {
            let start = window.resetsAt.addingTimeInterval(-window.duration)
            print(
                "claude \(window.limitKind): used \(window.usedFraction.map { Int($0 * 100) } ?? -1)%",
                "start \(start.formatted(date: .abbreviated, time: .shortened))",
                "resets \(window.resetsAt.formatted(date: .abbreviated, time: .shortened))",
                "open \(window.isOpen(at: now))"
            )
        }
    }

    /// Lists the Routines Wakebar manages on the signed-in account. Read-only:
    /// it creates, changes, and runs nothing.
    func testClaudeRoutinesListReadsTheSignedInAccount() async throws {
        try requireLiveTests()

        let routines = try await ClaudeRoutinesClient().listRoutines(credentialIntent: .background)

        for routine in routines {
            print(
                "routine id=\(routine.id) name=\"\(routine.name)\"",
                "cron=\(routine.cronExpression ?? "-") enabled=\(routine.enabled)",
                "prompt=\(routine.prompt.map { "\"\($0.prefix(80))\"" } ?? "-")"
            )
        }
    }

    func testClaudeStartNowReceivesProviderConfirmation() async throws {
        try requireLiveTests()
        let environment = ProcessInfo.processInfo.environment
        guard let schedulePath = environment["WAKEBAR_LIVE_SCHEDULE_FILE"] else {
            XCTFail("Set WAKEBAR_LIVE_SCHEDULE_FILE to a Wakebar schedule JSON file.")
            return
        }

        let data = try Data(contentsOf: URL(filePath: schedulePath))
        let schedule = try JSONDecoder().decode(WakeSchedule.self, from: data)
        XCTAssertTrue(schedule.includeClaude, "The live schedule must include Claude Code.")

        let coordinator = ProviderStartNowCoordinator()
        let outcome = try await coordinator.requestStart(for: .claude, schedule: schedule)

        guard case .started = outcome else {
            XCTFail("Claude accepted the Routine run, but usage did not confirm a new window within five minutes.")
            return
        }
    }

    private func requireLiveTests() throws {
        guard ProcessInfo.processInfo.environment["WAKEBAR_LIVE_PROVIDER_TESTS"] == "1" else {
            throw XCTSkip("Set WAKEBAR_LIVE_PROVIDER_TESTS=1 to run provider acceptance tests.")
        }
    }
}
