import Foundation

/// Reconstructs Claude Code's rolling usage window from session timestamps.
///
/// Claude Code writes no rate-limit snapshot, but every entry in its session
/// logs is timestamped. The window opens with the first message and runs a
/// fixed length, so the block boundaries can be rebuilt from the timestamps
/// alone — the same reconstruction `ccusage` performs.
///
/// The result is `.inferred`, never `.reported`. It cannot see usage from
/// another machine, from the web client, or from a session whose log Wakebar
/// cannot read, so it is a good estimate rather than an account.
public struct ClaudeUsageBlockCalculator: Sendable {
    /// Claude's window length. Not read from anywhere, because Claude Code
    /// publishes no figure — changing this is changing an assumption.
    public static let defaultWindowDuration: TimeInterval = 5 * 60 * 60

    private let windowDuration: TimeInterval
    private let calendar: Calendar

    public init(
        windowDuration: TimeInterval = ClaudeUsageBlockCalculator.defaultWindowDuration,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.windowDuration = windowDuration
        self.calendar = calendar
    }

    /// The window covering `now`, or nil when the last block has already closed
    /// and nothing is open.
    public func currentWindow(timestamps: [Date], now: Date) -> UsageWindow? {
        guard let start = currentBlockStart(timestamps: timestamps, now: now) else { return nil }
        let resetsAt = start.addingTimeInterval(windowDuration)
        guard now < resetsAt else { return nil }

        return UsageWindow(
            provider: .claude,
            duration: windowDuration,
            resetsAt: resetsAt,
            usedFraction: min(1, max(0, now.timeIntervalSince(start) / windowDuration)),
            observedAt: now,
            confidence: .inferred
        )
    }

    /// Where the block containing `now` began.
    ///
    /// A block starts at the first message after a quiet stretch longer than the
    /// window, or after the previous block ran out. The start is floored to the
    /// hour, which is how Claude's own accounting reports these blocks.
    public func currentBlockStart(timestamps: [Date], now: Date) -> Date? {
        let sorted = timestamps.sorted()
        guard let first = sorted.first else { return nil }

        var blockStart = floorToHour(first)
        var previous = first

        for timestamp in sorted.dropFirst() {
            let startsNewBlock = timestamp.timeIntervalSince(blockStart) >= windowDuration
                || timestamp.timeIntervalSince(previous) >= windowDuration
            if startsNewBlock {
                blockStart = floorToHour(timestamp)
            }
            previous = timestamp
        }

        // A block that ended before now leaves nothing open.
        guard now.timeIntervalSince(previous) < windowDuration else { return nil }
        return blockStart
    }

    private func floorToHour(_ date: Date) -> Date {
        calendar.date(
            from: calendar.dateComponents([.year, .month, .day, .hour], from: date)
        ) ?? date
    }
}
