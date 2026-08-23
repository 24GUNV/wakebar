import Foundation

/// Decides when the next session should fire so it opens a fresh usage window
/// the moment the current one closes.
///
/// This is the whole point of chaining: a fixed 5-hour cadence drifts out of
/// step as soon as the user works outside Wakebar's sessions, because their real
/// window started with *their* first message, not Wakebar's. Anchoring to the
/// reported reset keeps the two aligned.
///
/// When no provider reports a session window, the caller falls back to the
/// fixed slots — nothing here invents a window.
public struct ChainedSessionPlanner: Sendable {
    /// How long after a reset to fire. A session that races the reset reopens
    /// the window that just closed, wasting the whole chain, so it waits.
    public static let resetBuffer: TimeInterval = 60
    /// What a Claude session window is worth when the provider will not say.
    public static let assumedWindowDuration: TimeInterval = 5 * 60 * 60

    public let buffer: TimeInterval

    public init(buffer: TimeInterval = ChainedSessionPlanner.resetBuffer) {
        self.buffer = buffer
    }

    public struct Plan: Equatable, Sendable {
        /// When to fire, or nil when the cutoff has already passed today.
        public let firesAt: Date?
        /// The window this plan is chained to.
        public let window: UsageWindow

        public init(firesAt: Date?, window: UsageWindow) {
            self.firesAt = firesAt
            self.window = window
        }
    }

    /// The next session, chained to whichever open session window closes first.
    ///
    /// - Parameter cutoff: the latest a session may start. Past it the chain
    ///   stops for the day rather than waking the user's providers all night.
    public func nextSession(
        windows: [UsageWindow],
        now: Date,
        cutoff: Date?
    ) -> Plan? {
        let open = windows
            .filter(\.isSessionWindow)
            .filter { $0.isOpen(at: now) }

        guard let soonest = open.min(by: { $0.resetsAt < $1.resetsAt }) else { return nil }

        let firesAt = soonest.resetsAt.addingTimeInterval(buffer)
        if let cutoff, firesAt > cutoff {
            return Plan(firesAt: nil, window: soonest)
        }
        return Plan(firesAt: firesAt, window: soonest)
    }

    /// The window a user would call "current": the open session window closing
    /// soonest, which is the one that gates the next session.
    public func governingWindow(windows: [UsageWindow], now: Date) -> UsageWindow? {
        openSessionWindows(windows, now: now).min { $0.resetsAt < $1.resetsAt }
    }

    /// The window that gates one provider's next session.
    ///
    /// Providers keep independent windows and they drift apart the moment the
    /// user works in one and not the other. Chaining both off the soonest reset
    /// fires a session into a window that is still open, which does nothing and
    /// costs that provider its place in the chain.
    public func governingWindow(
        windows: [UsageWindow],
        now: Date,
        provider: ProviderID
    ) -> UsageWindow? {
        openSessionWindows(windows, now: now)
            .filter { $0.provider == provider }
            .min { $0.resetsAt < $1.resetsAt }
    }

    private func openSessionWindows(_ windows: [UsageWindow], now: Date) -> [UsageWindow] {
        windows
            .filter(\.isSessionWindow)
            .filter { $0.isOpen(at: now) }
    }
}
