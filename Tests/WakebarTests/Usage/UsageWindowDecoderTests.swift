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
        XCTAssertEqual(window.limitKind, .session)
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
        XCTAssertEqual(window.limitKind, .weekly)
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

    func testClaudeKeepsSessionWeeklyAndFableLimitsSeparate() throws {
        let body = """
        {
          "five_hour":{"utilization":10.0,"resets_at":"2026-08-21T14:02:10Z"},
          "seven_day":{"utilization":25.0,"resets_at":"2026-08-28T14:02:10Z"},
          "seven_day_fable":{"utilization":48.0,"resets_at":"2026-08-28T14:02:10Z"}
        }
        """

        let windows = try ClaudeUsageWindowDecoder().decode(body, observedAt: observedAt)

        XCTAssertEqual(windows.map(\.limitKind), [.session, .weekly, .weeklyFable])
        XCTAssertEqual(windows.map(\.usedFraction), [0.10, 0.25, 0.48])
    }

    func testClaudeDecodesLimitsArray() throws {
        let body = """
        {
          "five_hour":{"utilization":2.0,"resets_at":"2026-08-21T14:02:10Z"},
          "seven_day":{"utilization":3.0,"resets_at":"2026-08-28T14:02:10Z"},
          "limits":[
            {"kind":"session","percent":42,"resets_at":"2026-08-26T17:29:59.956703+00:00"},
            {"kind":"weekly_all","percent":44,"resets_at":"2026-08-28T10:59:59+00:00"},
            {"kind":"weekly_scoped","percent":68,"resets_at":"2026-08-28T10:59:59.957238+00:00","scope":{"model":{"id":null,"display_name":"Fable"}}}
          ],
          "experimental_field":{"ignored":true}
        }
        """

        let windows = try ClaudeUsageWindowDecoder().decode(body, observedAt: observedAt)

        XCTAssertEqual(windows.map(\.limitKind), [.session, .weekly, .weeklyFable])
        XCTAssertEqual(windows.map(\.duration), [18_000, 604_800, 604_800])
        XCTAssertEqual(windows.map(\.usedFraction), [0.42, 0.44, 0.68])
        XCTAssertEqual(windows.map(\.provider), [.claude, .claude, .claude])
        XCTAssertEqual(windows.map(\.confidence), [.reported, .reported, .reported])
        XCTAssertEqual(windows[0].resetsAt.timeIntervalSince1970, 1_787_765_399.956703, accuracy: 0.001)
        XCTAssertEqual(windows[1].resetsAt.timeIntervalSince1970, 1_787_914_799, accuracy: 0.001)
        XCTAssertEqual(windows[2].resetsAt.timeIntervalSince1970, 1_787_914_799.957238, accuracy: 0.001)
    }

    func testClaudeLimitsWinWithoutDuplicatingLegacyKinds() throws {
        let body = """
        {
          "five_hour":{"utilization":10,"resets_at":"2026-08-21T14:02:10Z"},
          "seven_day":{"utilization":20,"resets_at":"2026-08-28T14:02:10Z"},
          "seven_day_fable":{"utilization":30,"resets_at":"2026-08-28T14:02:10Z"},
          "limits":[
            {"kind":"session","percent":40,"resets_at":"2026-08-26T17:29:59Z"},
            {"kind":"weekly_all","percent":50,"resets_at":"2026-08-28T10:59:59Z"},
            {"kind":"weekly_scoped","percent":60,"resets_at":"2026-08-28T10:59:59Z","scope":{"model":{}}}
          ]
        }
        """

        let windows = try ClaudeUsageWindowDecoder().decode(body, observedAt: observedAt)

        XCTAssertEqual(windows.map(\.limitKind), [.session, .weekly, .weeklyFable])
        XCTAssertEqual(windows.map(\.usedFraction), [0.40, 0.50, 0.60])
    }

    func testClaudeSkipsWeeklyScopedLimitWithNullScope() throws {
        let body = """
        {"limits":[{"kind":"weekly_scoped","percent":68,"resets_at":"2026-08-28T10:59:59Z","scope":null}]}
        """

        XCTAssertTrue(try ClaudeUsageWindowDecoder().decode(body, observedAt: observedAt).isEmpty)
    }

    func testClaudeSkipsUnknownLimitKind() throws {
        let body = """
        {"limits":[{"kind":"daily","percent":68,"resets_at":"2026-08-28T10:59:59Z"}]}
        """

        XCTAssertTrue(try ClaudeUsageWindowDecoder().decode(body, observedAt: observedAt).isEmpty)
    }

    func testClaudeSkipsLimitWithNullResetDate() throws {
        let body = """
        {"limits":[{"kind":"session","percent":42,"resets_at":null}]}
        """

        XCTAssertTrue(try ClaudeUsageWindowDecoder().decode(body, observedAt: observedAt).isEmpty)
    }

    func testClaudeMapsLegacyModelWeeklyFieldToFable() throws {
        let body = """
        {"seven_day_sonnet":{"utilization":48.0,"resets_at":"2026-08-28T14:02:10Z"}}
        """

        let window = try XCTUnwrap(
            ClaudeUsageWindowDecoder().decode(body, observedAt: observedAt).first
        )

        XCTAssertEqual(window.limitKind, .weeklyFable)
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
