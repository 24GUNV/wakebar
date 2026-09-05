import Foundation

/// Decides when this Mac should send Codex its one-word wake.
///
/// Codex has no hosted schedule Wakebar can write to, so the wake is sent from
/// the app itself and only while it is running. That makes catching up the
/// main job here: a wake that was due while the Mac slept is still worth
/// sending the moment it is back, as long as the window it was meant to open
/// has not been opened by the user in the meantime.
public struct CodexWakePlanner: Sendable {
    public struct Decision: Equatable, Sendable {
        /// Send the wake now.
        public let firesNow: Bool
        /// The occurrence this decision settles, when one is due. The caller
        /// records it as handled whether or not a wake went out, so a window
        /// the user opened themselves does not keep a slot pending all day.
        public let dueAt: Date?
        /// When to look again. Nil when the schedule gives Codex nothing to do.
        public let nextCheck: Date?

        public init(firesNow: Bool, dueAt: Date?, nextCheck: Date?) {
            self.firesNow = firesNow
            self.dueAt = dueAt
            self.nextCheck = nextCheck
        }

        public static let nothing = Decision(firesNow: false, dueAt: nil, nextCheck: nil)
    }

    /// How long one wake is trusted before the reading is asked again. A
    /// reading taken seconds after a wake can still show the placeholder.
    public static let settleInterval: TimeInterval = 10 * 60

    private let calculator: ScheduleCalculator
    private let buffer: TimeInterval

    public init(
        calculator: ScheduleCalculator = ScheduleCalculator(),
        buffer: TimeInterval = ChainedSessionPlanner.resetBuffer
    ) {
        self.calculator = calculator
        self.buffer = buffer
    }

    /// - Parameter windows: the latest Codex reading. Session windows govern
    ///   when the plan reports any; a plan carrying only a weekly cap is woken
    ///   once after that cap resets. Missing readings are unknown and never
    ///   authorize a wake; the caller retries the usage read later.
    /// - Parameter lastHandledAt: the `dueAt` of the previous decision that
    ///   was acted on, or the time of the last wake sent.
    public func decide(
        schedule: WakeSchedule,
        windows: [UsageWindow],
        now: Date,
        lastHandledAt: Date?
    ) -> Decision {
        guard schedule.isEnabled, schedule.isValid, schedule.includeCodex else {
            return .nothing
        }

        let tracked = trackedWindows(in: windows, now: now)
        guard !tracked.isEmpty else {
            return Decision(firesNow: false, dueAt: nil, nextCheck: now.addingTimeInterval(Self.settleInterval))
        }
        let needsWake = tracked.contains(where: \.isUnstarted)
        let soonestReset = tracked.filter { !$0.isUnstarted }.map(\.resetsAt).min()

        if let lastHandledAt, now < lastHandledAt.addingTimeInterval(Self.settleInterval),
           schedule.cadence == .continuous {
            return Decision(
                firesNow: false,
                dueAt: nil,
                nextCheck: lastHandledAt.addingTimeInterval(Self.settleInterval)
            )
        }

        switch schedule.cadence {
        case .continuous:
            if needsWake {
                return Decision(firesNow: true, dueAt: now, nextCheck: now.addingTimeInterval(Self.settleInterval))
            }
            let next = soonestReset.map { $0.addingTimeInterval(buffer) }
            return Decision(firesNow: false, dueAt: nil, nextCheck: next)

        case .schedule:
            let lead = TimeInterval(schedule.sessionLeadMinutes * 60)
            let nextSlot = calculator.nextSessionStart(after: now, for: schedule)
            let previousSlot = calculator
                .previousWakeOccurrence(before: now.addingTimeInterval(lead + 1), for: schedule)?
                .addingTimeInterval(-lead)

            guard let previousSlot, previousSlot <= now,
                  lastHandledAt.map({ $0 < previousSlot }) ?? true
            else {
                return Decision(firesNow: false, dueAt: nil, nextCheck: nextSlot)
            }
            return Decision(firesNow: needsWake, dueAt: previousSlot, nextCheck: nextSlot)
        }
    }

    private func trackedWindows(in windows: [UsageWindow], now: Date) -> [UsageWindow] {
        let codex = windows.filter { $0.provider == .codex && $0.isOpen(at: now) }
        let sessions = codex.filter(\.isSessionWindow)
        return sessions.isEmpty ? codex : sessions
    }
}
