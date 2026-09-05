import Foundation
import WakebarCore
import XCTest
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

final class ProviderStartNowCoordinatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_787_500_000)

    func testClaudeRequestsRoutineAndConfirmsNewProviderWindow() async throws {
        let baseline = window(provider: .claude, resetOffset: 60 * 60, used: 0.2)
        let changed = window(provider: .claude, resetOffset: 5 * 60 * 60, used: 0)
        let usage = StubProviderUsageReading(readings: [[baseline], [changed]])
        let claude = StubClaudeStartRequester()
        let coordinator = makeCoordinator(
            usageReaders: [.claude: usage],
            claude: claude
        )

        let outcome = try await coordinator.requestStart(for: .claude, schedule: .default)
        let requestCount = await claude.requestCount

        XCTAssertEqual(outcome, .started(changed))
        XCTAssertEqual(requestCount, 1)
    }

    /// A plan that reports only a weekly cap opens that cap. Before the wake
    /// Codex describes it as a full, unused week whose reset keeps pace with
    /// the clock; afterwards the reset is pinned.
    func testCodexSendsThePromptAndConfirmsTheWeeklyWindowPinning() async throws {
        let week: TimeInterval = 7 * 24 * 60 * 60
        let placeholder = UsageWindow(
            provider: .codex,
            duration: week,
            resetsAt: now.addingTimeInterval(week),
            usedFraction: 0,
            observedAt: now,
            confidence: .reported
        )
        let pinned = UsageWindow(
            provider: .codex,
            duration: week,
            resetsAt: now.addingTimeInterval(week - 10 * 60),
            usedFraction: 0,
            observedAt: now,
            confidence: .reported
        )
        let usage = StubProviderUsageReading(readings: [[placeholder], [pinned]])
        let codex = StubCodexStartRequester()
        let coordinator = makeCoordinator(
            usageReaders: [.codex: usage],
            codex: codex
        )

        let outcome = try await coordinator.requestStart(for: .codex, schedule: .default)
        let prompts = await codex.prompts

        XCTAssertEqual(outcome, .started(pinned))
        XCTAssertEqual(prompts, ["hi"])
    }

    func testCodexRequestFailurePropagates() async {
        let codex = StubCodexStartRequester(error: UsageWindowProviderIssue.missingCredentials)
        let usage = StubProviderUsageReading(readings: [[]])
        let coordinator = makeCoordinator(usageReaders: [.codex: usage], codex: codex)

        do {
            _ = try await coordinator.requestStart(for: .codex, schedule: .default)
            XCTFail("Expected the credential error")
        } catch {
            XCTAssertEqual(error as? UsageWindowProviderIssue, .missingCredentials)
        }
    }

    private func makeCoordinator(
        usageReaders: [ProviderID: any ProviderUsageReading],
        claude: any ClaudeStartRequesting = StubClaudeStartRequester(),
        codex: any CodexStartRequesting = StubCodexStartRequester()
    ) -> ProviderStartNowCoordinator {
        let now = self.now
        return ProviderStartNowCoordinator(
            usageReaders: usageReaders,
            claudeRequester: claude,
            codexRequester: codex,
            sleeper: ImmediateUsageWindowPollingSleeper(),
            now: { now },
            pollCount: 1
        )
    }

    private func window(
        provider: ProviderID,
        resetOffset: TimeInterval,
        used: Double
    ) -> UsageWindow {
        UsageWindow(
            provider: provider,
            duration: 5 * 60 * 60,
            resetsAt: now.addingTimeInterval(resetOffset),
            usedFraction: used,
            observedAt: now,
            confidence: .reported
        )
    }
}
