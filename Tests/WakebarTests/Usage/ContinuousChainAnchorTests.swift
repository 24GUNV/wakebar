import XCTest
@testable import WakebarCore

final class ContinuousChainAnchorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_779_800_000)

    func testAnchorsOneMinuteAfterTheOpenClaudeReset() {
        var anchor = ContinuousChainAnchor()

        let moved = anchor.observe(windows: [claude(resetsIn: 3600)], now: now)

        XCTAssertTrue(moved)
        XCTAssertEqual(anchor.firesAt, now.addingTimeInterval(3600 + ChainedSessionPlanner.resetBuffer))
    }

    func testIgnoresCodexAndWeeklyWindows() {
        var anchor = ContinuousChainAnchor()
        let codex = UsageWindow(
            provider: .codex,
            duration: 5 * 60 * 60,
            resetsAt: now.addingTimeInterval(1800),
            observedAt: now,
            confidence: .reported
        )
        let weekly = UsageWindow(
            provider: .claude,
            duration: 7 * 24 * 60 * 60,
            resetsAt: now.addingTimeInterval(3 * 24 * 60 * 60),
            observedAt: now,
            confidence: .reported
        )

        XCTAssertFalse(anchor.observe(windows: [codex, weekly], now: now))
        XCTAssertNil(anchor.firesAt)
    }

    func testAnUnchangedResetIsNotAMove() {
        var anchor = ContinuousChainAnchor()
        anchor.observe(windows: [claude(resetsIn: 3600)], now: now)

        let later = now.addingTimeInterval(600)
        let moved = anchor.observe(
            windows: [claude(resetsIn: 3600 - 600, at: later)],
            now: later
        )

        XCTAssertFalse(moved)
    }

    /// Minutes after the fire, the old window is closed and the new one is not
    /// yet reported. Dropping the fire then would delete the Routine that is
    /// opening the window.
    func testKeepsTheFireThroughTheGraceAfterAReset() {
        var anchor = ContinuousChainAnchor()
        anchor.observe(windows: [claude(resetsIn: 3600)], now: now)
        let firesAt = anchor.firesAt

        let justAfter = now.addingTimeInterval(3600 + 5 * 60)
        XCTAssertFalse(anchor.observe(windows: [], now: justAfter))
        XCTAssertEqual(anchor.firesAt, firesAt)
    }

    func testClearsTheFireOnceTheGraceHasPassedWithNoWindow() {
        var anchor = ContinuousChainAnchor()
        anchor.observe(windows: [claude(resetsIn: 3600)], now: now)

        let later = now.addingTimeInterval(3600 + ContinuousChainAnchor.grace + 120)
        XCTAssertTrue(anchor.observe(windows: [], now: later))
        XCTAssertNil(anchor.firesAt)
    }

    func testFollowsTheNewWindowAfterAFire() {
        var anchor = ContinuousChainAnchor()
        anchor.observe(windows: [claude(resetsIn: 3600)], now: now)

        let afterFire = now.addingTimeInterval(3600 + 3 * 60)
        let moved = anchor.observe(
            windows: [claude(resetsIn: 5 * 60 * 60 - 120, at: afterFire)],
            now: afterFire
        )

        XCTAssertTrue(moved)
        XCTAssertEqual(
            anchor.firesAt,
            afterFire.addingTimeInterval(5 * 60 * 60 - 120 + ChainedSessionPlanner.resetBuffer)
        )
    }

    private func claude(resetsIn seconds: TimeInterval, at date: Date? = nil) -> UsageWindow {
        let observed = date ?? now
        return UsageWindow(
            provider: .claude,
            duration: 5 * 60 * 60,
            resetsAt: observed.addingTimeInterval(seconds),
            observedAt: observed,
            confidence: .reported
        )
    }
}
