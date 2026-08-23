import Foundation
import WakebarCore
import XCTest
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

final class UsageSummaryViewModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_787_500_000)

    func testShowsClaudeSessionWeeklyAndFableBars() throws {
        let presentation = makePresentation(
            windows: [
                window(duration: 5 * 60 * 60, resetOffset: 2 * 60 * 60 + 15 * 60, used: 1.2),
                window(duration: 7 * 24 * 60 * 60, resetOffset: 3 * 24 * 60 * 60 + 2 * 60 * 60, used: -0.1),
                window(
                    kind: .weeklyFable,
                    duration: 7 * 24 * 60 * 60,
                    resetOffset: 3 * 24 * 60 * 60 + 2 * 60 * 60,
                    used: 0.48
                ),
            ]
        )

        let provider = try XCTUnwrap(presentation.providers.first)
        XCTAssertEqual(provider.bars.map(\.label), ["Five-hour", "Weekly", "Fable weekly"])
        XCTAssertEqual(provider.bars.map(\.usedFraction), [1, 0, 0.48])
        XCTAssertEqual(provider.bars.map(\.usedText), ["100% used", "0% used", "48% used"])
        XCTAssertEqual(
            provider.bars.map(\.resetText),
            ["resets in 2h 15m", "resets in 3d 2h", "resets in 3d 2h"]
        )
    }

    func testCodexShowsOnlyItsWeeklyBar() throws {
        let weekly = UsageWindow(
            provider: .codex,
            limitKind: .weekly,
            duration: 7 * 24 * 60 * 60,
            resetsAt: now.addingTimeInterval(3 * 24 * 60 * 60),
            usedFraction: 0.25,
            observedAt: now,
            confidence: .reported
        )
        let presentation = UsageSummaryViewModel(
            enabledProviders: [.codex],
            events: [],
            windows: [weekly],
            issues: [:],
            now: now
        )

        let provider = try XCTUnwrap(presentation.providers.first)
        XCTAssertEqual(provider.bars.map(\.label), ["Weekly"])
    }

    func testSelectsEarliestCompiledWindowStartForCountdown() {
        let later = event(offset: 2 * 60 * 60, provider: .claude)
        let earlier = event(offset: 35 * 60, provider: .codex)

        let presentation = makePresentation(events: [later, earlier])

        XCTAssertEqual(presentation.nextWindowText, "Next window: in 35m")
    }

    func testUsesNowWhenScheduleIsIdleAndAWindowIsOpen() {
        let presentation = makePresentation(
            windows: [window(duration: 5 * 60 * 60, resetOffset: 60 * 60, used: 0.2)]
        )

        XCTAssertEqual(presentation.nextWindowText, "Next window: now")
    }

    func testShowsActionableAuthenticationIssueWithoutBars() throws {
        let presentation = UsageSummaryViewModel(
            enabledProviders: [.codex],
            events: [],
            windows: [],
            issues: [.codex: .missingCredentials],
            now: now
        )

        XCTAssertEqual(
            try XCTUnwrap(presentation.providers.first).issueMessage,
            "Run `codex login`"
        )
    }

    private func makePresentation(
        events: [ScheduledEvent] = [],
        windows: [UsageWindow] = []
    ) -> UsageSummaryViewModel {
        UsageSummaryViewModel(
            enabledProviders: [.claude],
            events: events,
            windows: windows,
            issues: [:],
            now: now
        )
    }

    private func window(
        kind: UsageLimitKind? = nil,
        duration: TimeInterval,
        resetOffset: TimeInterval,
        used: Double?
    ) -> UsageWindow {
        UsageWindow(
            provider: .claude,
            limitKind: kind,
            duration: duration,
            resetsAt: now.addingTimeInterval(resetOffset),
            usedFraction: used,
            observedAt: now,
            confidence: .reported
        )
    }

    private func event(offset: TimeInterval, provider: ProviderID) -> ScheduledEvent {
        let scheduleID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")
        guard let scheduleID else {
            preconditionFailure("The deterministic schedule identifier is invalid.")
        }
        return ScheduledEvent(
            scheduleID: scheduleID,
            date: now.addingTimeInterval(offset),
            wakeDate: now.addingTimeInterval(offset + 10 * 60),
            kind: .providerSession(provider, phase: .initial)
        )
    }
}
