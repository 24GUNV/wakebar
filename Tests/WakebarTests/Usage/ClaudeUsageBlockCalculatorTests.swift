import XCTest
@testable import WakebarCore

final class ClaudeUsageBlockCalculatorTests: XCTestCase {
    private let calculator = ClaudeUsageBlockCalculator()

    private func date(_ hour: Int, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 21
        components.hour = hour
        components.minute = minute
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: components)!
    }

    private var utcCalculator: ClaudeUsageBlockCalculator {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return ClaudeUsageBlockCalculator(calendar: calendar)
    }

    /// The window opens with the first message, floored to the hour, which is
    /// how Claude's own accounting reports these blocks.
    func testWindowStartsAtTheFirstMessageHour() throws {
        let window = try XCTUnwrap(
            utcCalculator.currentWindow(
                timestamps: [date(9, 17), date(9, 40), date(10, 5)],
                now: date(11)
            )
        )

        XCTAssertEqual(window.resetsAt, date(14))
        XCTAssertEqual(window.duration, 5 * 60 * 60)
        XCTAssertEqual(window.confidence, .inferred)
    }

    /// Nothing is open once the block has run out.
    func testClosedBlockYieldsNoWindow() {
        XCTAssertNil(
            utcCalculator.currentWindow(timestamps: [date(9, 17)], now: date(15))
        )
    }

    /// A quiet stretch longer than the window means the next message opened a
    /// new one, so the reset moves with it.
    func testQuietStretchOpensANewBlock() throws {
        let window = try XCTUnwrap(
            utcCalculator.currentWindow(
                timestamps: [date(1), date(2), date(9, 30)],
                now: date(10)
            )
        )
        XCTAssertEqual(window.resetsAt, date(14))
    }

    /// Continuous work past the window rolls into a fresh block rather than
    /// extending the old one.
    func testWorkPastTheWindowRollsOver() throws {
        let stamps = stride(from: 0, through: 7, by: 1).map { date(8 + $0) }
        let window = try XCTUnwrap(utcCalculator.currentWindow(timestamps: stamps, now: date(15, 30)))

        XCTAssertEqual(window.resetsAt, date(18))
    }

    func testNoTimestampsYieldNoWindow() {
        XCTAssertNil(utcCalculator.currentWindow(timestamps: [], now: date(10)))
    }

    /// It is an estimate, and it says so — this is what stops the UI claiming
    /// the provider confirmed something it never reported.
    func testAlwaysReportsItselfAsInferred() throws {
        let window = try XCTUnwrap(
            utcCalculator.currentWindow(timestamps: [date(9)], now: date(10))
        )
        XCTAssertEqual(window.confidence, .inferred)
        XCTAssertEqual(try XCTUnwrap(window.usedFraction), 0.2, accuracy: 0.0001)
    }
}
