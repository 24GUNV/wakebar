import XCTest
@testable import WakebarCore

final class CodexRateLimitReaderTests: XCTestCase {
    private let reader = CodexRateLimitReader()
    private let observedAt = Date(timeIntervalSince1970: 1_779_800_000)

    /// The shape Codex actually wrote when it reported both a session window
    /// and a weekly cap.
    private let bothWindows = """
    {"type":"event","payload":{"rate_limits":{"limit_id":"codex","limit_name":null,\
    "primary":{"used_percent":54.0,"window_minutes":300,"resets_at":1779810921},\
    "secondary":{"used_percent":13.0,"window_minutes":10080,"resets_at":1780239431},\
    "credits":null,"plan_type":"prolite","rate_limit_reached_type":null}}}
    """

    /// The shape on a plan that reports only a weekly cap, taken from a live
    /// session log. `secondary` is null and there is no session window at all.
    private let weeklyOnly = """
    {"type":"event","payload":{"rate_limits":{"limit_id":"codex","limit_name":null,\
    "primary":{"used_percent":14.0,"window_minutes":10080,"resets_at":1787806845},\
    "secondary":null,"credits":{"has_credits":false,"unlimited":false,"balance":"0"},\
    "plan_type":"prolite","rate_limit_reached_type":null}}}
    """

    func testReadsTheSessionWindow() throws {
        let window = try XCTUnwrap(reader.window(fromSessionLog: bothWindows, observedAt: observedAt))

        XCTAssertEqual(window.provider, .codex)
        XCTAssertEqual(window.duration, 300 * 60)
        XCTAssertEqual(window.resetsAt, Date(timeIntervalSince1970: 1_779_810_921))
        XCTAssertEqual(try XCTUnwrap(window.usedFraction), 0.54, accuracy: 0.0001)
        XCTAssertEqual(window.confidence, .reported)
    }

    /// A weekly cap is not something a morning session can reopen, so it must
    /// never be handed to the planner as the window to chain against.
    func testIgnoresAWeeklyCap() throws {
        XCTAssertNil(reader.window(fromSessionLog: weeklyOnly, observedAt: observedAt))

        let all = reader.allWindows(fromSessionLog: weeklyOnly, observedAt: observedAt)
        XCTAssertEqual(all.count, 1)
        XCTAssertFalse(try XCTUnwrap(all.first).isSessionWindow)
    }

    /// The session window is reported in whichever slot the plan puts it, so
    /// position must not be trusted.
    func testFindsTheSessionWindowInEitherSlot() throws {
        let swapped = """
        {"rate_limits":{"primary":{"used_percent":13.0,"window_minutes":10080,"resets_at":1780239431},\
        "secondary":{"used_percent":54.0,"window_minutes":300,"resets_at":1779810921}}}
        """
        let window = try XCTUnwrap(reader.window(fromSessionLog: swapped, observedAt: observedAt))
        XCTAssertEqual(window.duration, 300 * 60)
    }

    /// Codex appends snapshots as it works; the last one is the current one.
    func testUsesTheLastSnapshotInTheLog() throws {
        let log = bothWindows + "\n" + """
        {"rate_limits":{"primary":{"used_percent":91.0,"window_minutes":300,"resets_at":1779899999}}}
        """
        let window = try XCTUnwrap(reader.window(fromSessionLog: log, observedAt: observedAt))
        XCTAssertEqual(window.resetsAt, Date(timeIntervalSince1970: 1_779_899_999))
    }

    /// An undocumented private format will change. A wrong window is worse than
    /// none, so anything that does not fit reads as nothing.
    func testMalformedInputYieldsNoWindow() {
        XCTAssertNil(reader.window(fromSessionLog: "", observedAt: observedAt))
        XCTAssertNil(reader.window(fromSessionLog: "no snapshot here", observedAt: observedAt))
        XCTAssertNil(reader.window(fromSessionLog: #"{"rate_limits":{"primary":"#, observedAt: observedAt))
        XCTAssertNil(reader.window(
            fromSessionLog: #"{"rate_limits":{"primary":{"used_percent":54.0}}}"#,
            observedAt: observedAt
        ))
        XCTAssertNil(reader.window(
            fromSessionLog: #"{"rate_limits":{"primary":{"window_minutes":0,"resets_at":1779810921}}}"#,
            observedAt: observedAt
        ))
    }

    /// A brace inside a string must not end the object early.
    func testToleratesBracesInsideStrings() throws {
        let log = #"{"rate_limits":{"limit_name":"a } brace","primary":{"window_minutes":300,"resets_at":1779810921}}}"#
        let window = try XCTUnwrap(reader.window(fromSessionLog: log, observedAt: observedAt))
        XCTAssertEqual(window.duration, 300 * 60)
    }
}
