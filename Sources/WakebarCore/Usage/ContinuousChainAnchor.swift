import Foundation

/// The one cloud-side fire an "Every reset" schedule is waiting on.
///
/// A Routine can only fire on a cron, so the chain lives in the cloud as a
/// single Routine whose time Wakebar rewrites after each usage reading. This
/// anchor decides what that time is from the windows Claude reports, and it
/// says when the time moved so the app knows a rewrite is due.
public struct ContinuousChainAnchor: Equatable, Sendable {
    /// How long a reading with no open window keeps the last fire alive.
    ///
    /// The Routine fires a minute after the reset. A reading taken in the
    /// minutes after that sees the old window closed and the new one not yet
    /// reported, and dropping the fire then would delete the Routine that is
    /// opening the window. Past the grace, no window means the chain broke —
    /// the Mac was asleep, or the fire never landed — and the fixed morning
    /// slot is what restarts it.
    public static let grace: TimeInterval = 15 * 60

    public private(set) var firesAt: Date?

    private let chain: ChainedSessionPlanner

    public init(firesAt: Date? = nil, chain: ChainedSessionPlanner = ChainedSessionPlanner()) {
        self.firesAt = firesAt
        self.chain = chain
    }

    /// Folds one usage reading into the anchor. Returns true when the fire
    /// moved, which is when the cloud Routine needs its cron rewritten.
    @discardableResult
    public mutating func observe(windows: [UsageWindow], now: Date) -> Bool {
        let claudeWindows = windows.filter { $0.provider == .claude }
        let next = chain.nextSession(windows: claudeWindows, now: now, cutoff: nil)?.firesAt

        let updated: Date?
        if let next {
            updated = next
        } else if let firesAt, now < firesAt.addingTimeInterval(Self.grace) {
            updated = firesAt
        } else {
            updated = nil
        }

        guard updated != firesAt else { return false }
        firesAt = updated
        return true
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.firesAt == rhs.firesAt
    }
}
