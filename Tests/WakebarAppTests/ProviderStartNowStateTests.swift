import Foundation
import WakebarCore
import XCTest
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

final class ProviderStartNowStateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_787_500_000)

    func testStartedWindowStartIsTheProviderWindowStartNotThePollTime() {
        let window = sessionWindow(resetOffset: 4 * 60 * 60 + 30 * 60)

        let state = ProviderStartNowState.started(window)

        XCTAssertEqual(state.startedWindowStart, now.addingTimeInterval(-30 * 60))
    }

    func testStartedStateSurvivesWhileItsWindowIsOpen() {
        let window = sessionWindow(resetOffset: 60 * 60)
        let state = ProviderStartNowState.started(window)

        XCTAssertEqual(state.reconciled(with: [window], now: now), state)
        XCTAssertEqual(state.reconciled(with: [], now: now), state)
    }

    func testStartedStateClearsOnceItsWindowHasClosed() {
        let window = sessionWindow(resetOffset: 60 * 60)
        let state = ProviderStartNowState.started(window)

        let later = now.addingTimeInterval(60 * 60)

        XCTAssertEqual(state.reconciled(with: [window], now: later), .idle)
    }

    func testStartedStateClearsWhenALaterSessionWindowReplacesIt() {
        let window = sessionWindow(resetOffset: 60 * 60)
        let replacement = sessionWindow(resetOffset: 5 * 60 * 60)
        let state = ProviderStartNowState.started(window)

        XCTAssertEqual(state.reconciled(with: [replacement], now: now), .idle)
    }

    func testWeeklyWindowsAndOtherProvidersDoNotClearAStartedState() {
        let window = sessionWindow(resetOffset: 60 * 60)
        let weekly = UsageWindow(
            provider: .claude,
            duration: 7 * 24 * 60 * 60,
            resetsAt: now.addingTimeInterval(6 * 24 * 60 * 60),
            usedFraction: 0.1,
            observedAt: now,
            confidence: .reported
        )
        let codex = UsageWindow(
            provider: .codex,
            duration: 5 * 60 * 60,
            resetsAt: now.addingTimeInterval(5 * 60 * 60),
            usedFraction: 0,
            observedAt: now,
            confidence: .reported
        )
        let state = ProviderStartNowState.started(window)

        XCTAssertEqual(state.reconciled(with: [weekly, codex], now: now), state)
    }

    func testOtherStatesAreUntouched() {
        let window = sessionWindow(resetOffset: 5 * 60 * 60)

        XCTAssertEqual(ProviderStartNowState.idle.reconciled(with: [window], now: now), .idle)
        XCTAssertEqual(ProviderStartNowState.requested.reconciled(with: [window], now: now), .requested)
        XCTAssertEqual(ProviderStartNowState.unconfirmed.reconciled(with: [window], now: now), .unconfirmed)
        XCTAssertNil(ProviderStartNowState.requested.startedWindowStart)
    }

    private func sessionWindow(resetOffset: TimeInterval) -> UsageWindow {
        UsageWindow(
            provider: .claude,
            duration: 5 * 60 * 60,
            resetsAt: now.addingTimeInterval(resetOffset),
            usedFraction: 0,
            observedAt: now,
            confidence: .reported
        )
    }
}
