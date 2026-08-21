import XCTest
@testable import WakebarCore

final class UsageWindowDecoderTests: XCTestCase {
    private let observedAt = Date(timeIntervalSince1970: 1_779_800_000)

    func testCodexClassifiesWindowsByDuration() throws {
        let body = """
        {
          "primary_window": {"used_percent": 42.0, "reset_at": 1779810921, "limit_window_seconds": 18000},
          "secondary_window": {"used_percent": 13.0, "reset_at": 1780239431, "limit_window_seconds": 604800}
        }
        """

        let windows = try CodexUsageWindowDecoder().decode(body, observedAt: observedAt)

        XCTAssertEqual(windows.count, 2)
        XCTAssertTrue(windows[0].isSessionWindow)
        XCTAssertEqual(windows[0].duration, 300 * 60)
        XCTAssertEqual(windows[0].usedFraction, 0.42)
        XCTAssertEqual(windows[0].resetsAt, Date(timeIntervalSince1970: 1_779_810_921))
        XCTAssertFalse(windows[1].isSessionWindow)
        XCTAssertEqual(windows[1].duration, 10080 * 60)
        XCTAssertEqual(windows[1].confidence, .reported)
    }

    func testCodexWeeklyOnlyDoesNotBecomeASessionWindow() throws {
        let body = """
        {"primary_window":{"used_percent":14.0,"reset_at":1787806845,"limit_window_seconds":604800},"secondary_window":null}
        """

        let windows = try CodexUsageWindowDecoder().decode(body, observedAt: observedAt)

        XCTAssertEqual(windows.count, 1)
        XCTAssertFalse(windows[0].isSessionWindow)
    }

    func testCodexBothNullIsEmpty() throws {
        let body = "{" + "\"primary_window\":null,\"secondary_window\":null}"

        XCTAssertTrue(try CodexUsageWindowDecoder().decode(body, observedAt: observedAt).isEmpty)
    }

    func testClaudeFiveHourWithRealUtilizationIsReportedSessionWindow() throws {
        let body = """
        {"five_hour":{"utilization":0.0,"resets_at":"2026-08-21T14:02:10.552Z"}}
        """

        let windows = try ClaudeUsageWindowDecoder().decode(body, observedAt: observedAt)

        let window = try XCTUnwrap(windows.first)
        XCTAssertTrue(window.isSessionWindow)
        XCTAssertEqual(window.usedFraction, 0.0)
        XCTAssertEqual(window.confidence, .reported)
        XCTAssertEqual(
            window.resetsAt.timeIntervalSince1970,
            1_787_320_930.552,
            accuracy: 0.001
        )
    }

    func testClaudeSyntheticFiveHourWithoutUtilizationIsIgnored() throws {
        let body = """
        {"five_hour":{"utilization":null,"resets_at":"2026-08-21T14:02:10.552Z"}}
        """

        XCTAssertTrue(try ClaudeUsageWindowDecoder().decode(body, observedAt: observedAt).isEmpty)
    }

    func testClaudeSevenDayIsWeekly() throws {
        let body = """
        {"seven_day":{"utilization":25.5,"resets_at":"2026-08-28T14:02:10Z"}}
        """

        let window = try XCTUnwrap(ClaudeUsageWindowDecoder().decode(body, observedAt: observedAt).first)

        XCTAssertFalse(window.isSessionWindow)
        XCTAssertEqual(window.duration, 7 * 24 * 60 * 60)
        XCTAssertEqual(try XCTUnwrap(window.usedFraction), 0.255, accuracy: 0.0001)
    }

    func testClaudeParsesFractionalAndWholeSecondISO8601Dates() throws {
        let body = """
        {
          "five_hour":{"utilization":10,"resets_at":"2026-08-21T14:02:10.552Z"},
          "seven_day":{"utilization":20,"resets_at":"2026-08-28T14:02:10Z"}
        }
        """

        let windows = try ClaudeUsageWindowDecoder().decode(body, observedAt: observedAt)

        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(
            windows[0].resetsAt.timeIntervalSince1970,
            1_787_320_930.552,
            accuracy: 0.001
        )
        XCTAssertEqual(
            windows[1].resetsAt.timeIntervalSince1970,
            1_787_925_730,
            accuracy: 0.001
        )
    }

    /// seven_day, seven_day_opus and seven_day_sonnet are three readings of one
    /// weekly limit. Three rows all labelled "Claude Code weekly" would be the
    /// same fact printed three times, so only the binding one survives.
    func testClaudeCollapsesTheWeeklyCapsToTheBindingOne() throws {
        let body = """
        {
          "seven_day":{"utilization":25.0,"resets_at":"2026-08-28T14:02:10Z"},
          "seven_day_opus":{"utilization":81.0,"resets_at":"2026-08-28T14:02:10Z"},
          "seven_day_sonnet":{"utilization":12.0,"resets_at":"2026-08-28T14:02:10Z"}
        }
        """

        let windows = try ClaudeUsageWindowDecoder().decode(body, observedAt: observedAt)

        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(try XCTUnwrap(windows[0].usedFraction), 0.81, accuracy: 0.0001)
    }

    /// Whitelisting today's two window lengths would drop a third the day a plan
    /// gains one, and a dropped window reads as a provider Wakebar cannot see.
    func testCodexKeepsAWindowLengthItHasNotSeenBefore() throws {
        let body = """
        {"primary_window":{"used_percent":30.0,"reset_at":1779810921,"limit_window_seconds":86400},
         "secondary_window":null}
        """

        let windows = try CodexUsageWindowDecoder().decode(body, observedAt: observedAt)

        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows[0].duration, 86400)
        XCTAssertFalse(windows[0].isSessionWindow, "A day-long window is not a session window.")
    }
}
