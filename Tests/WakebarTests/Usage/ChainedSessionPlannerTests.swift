import XCTest
@testable import WakebarCore

final class ChainedSessionPlannerTests: XCTestCase {
    private let planner = ChainedSessionPlanner()
    private let now = Date(timeIntervalSince1970: 1_779_800_000)

    private func window(
        _ provider: ProviderID,
        resetsIn seconds: TimeInterval,
        duration: TimeInterval = 5 * 60 * 60,
        confidence: UsageWindow.Confidence = .reported
    ) -> UsageWindow {
        UsageWindow(
            provider: provider,
            duration: duration,
            resetsAt: now.addingTimeInterval(seconds),
            observedAt: now,
            confidence: confidence
        )
    }

    /// The next session fires just after the reset, not on it — a session that
    /// races the reset reopens the window that just closed.
    func testFiresJustAfterTheSoonestReset() throws {
        let plan = try XCTUnwrap(
            planner.nextSession(
                windows: [window(.codex, resetsIn: 3600), window(.claude, resetsIn: 7200)],
                now: now,
                cutoff: nil
            )
        )

        XCTAssertEqual(plan.window.provider, .codex)
        XCTAssertEqual(plan.firesAt, now.addingTimeInterval(3600 + 60))
    }

    /// A weekly cap is not a window a session can reopen.
    func testIgnoresNonSessionWindows() {
        XCTAssertNil(
            planner.nextSession(
                windows: [window(.codex, resetsIn: 3600, duration: 10080 * 60)],
                now: now,
                cutoff: nil
            )
        )
    }

    /// Past the cutoff the chain stops for the day instead of waking the
    /// providers all night. The window is still reported so the UI can say why.
    func testStopsAtTheCutoff() throws {
        let plan = try XCTUnwrap(
            planner.nextSession(
                windows: [window(.codex, resetsIn: 3600)],
                now: now,
                cutoff: now.addingTimeInterval(1800)
            )
        )

        XCTAssertNil(plan.firesAt)
        XCTAssertEqual(plan.window.provider, .codex)
    }

    /// An already-closed window cannot be chained against; the caller falls
    /// back to fixed slots rather than firing immediately.
    func testClosedWindowsAreNotChained() {
        XCTAssertNil(
            planner.nextSession(windows: [window(.codex, resetsIn: -60)], now: now, cutoff: nil)
        )
    }

    func testNoWindowsMeansNoPlan() {
        XCTAssertNil(planner.nextSession(windows: [], now: now, cutoff: nil))
    }

    func testGoverningWindowIsTheOneClosingSoonest() throws {
        let governing = try XCTUnwrap(
            planner.governingWindow(
                windows: [window(.claude, resetsIn: 7200), window(.codex, resetsIn: 3600)],
                now: now
            )
        )
        XCTAssertEqual(governing.provider, .codex)
    }
}
