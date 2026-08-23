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

        XCTAssertEqual(outcome, .started(now))
        XCTAssertEqual(requestCount, 1)
    }

    func testCodexCopiesMinimalPromptWithoutPollingForAFiveHourWindow() async throws {
        let codex = StubCodexStartRequester()
        let coordinator = makeCoordinator(
            usageReaders: [:],
            codex: codex
        )

        let outcome = try await coordinator.requestStart(for: .codex, schedule: .default)
        let prompts = await codex.prompts

        XCTAssertEqual(outcome, .unconfirmed)
        XCTAssertEqual(prompts, ["hi"])
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
