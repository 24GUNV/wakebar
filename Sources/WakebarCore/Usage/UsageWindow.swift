import Foundation

/// What a provider says about the usage window a session opens.
///
/// Wakebar's whole reason to fire an early session is to start one of these, so
/// knowing when the current one ends is what lets the next session be scheduled
/// against reality instead of against a fixed clock time.
public struct UsageWindow: Equatable, Sendable {
    public let provider: ProviderID
    /// Which provider limit this reading describes.
    public let limitKind: UsageLimitKind
    /// How long the window runs. Providers report this per plan, so it is read
    /// rather than assumed — a plan with a weekly cap reports 10080.
    public let duration: TimeInterval
    /// When the window ends and a new one can be opened.
    public let resetsAt: Date
    /// How much of the window is spent, when the provider reports it.
    public let usedFraction: Double?
    /// When this reading was taken. A snapshot written by the last session is
    /// still authoritative about `resetsAt` but stale about `usedFraction`.
    public let observedAt: Date
    /// Whether the provider stated this window or Wakebar inferred it.
    public let confidence: Confidence

    public enum Confidence: Equatable, Sendable {
        /// Read from a snapshot the provider itself wrote.
        case reported
        /// Reconstructed from session timestamps. Right in the normal case, but
        /// blind to usage from another machine or another client.
        case inferred
    }

    public init(
        provider: ProviderID,
        limitKind: UsageLimitKind? = nil,
        duration: TimeInterval,
        resetsAt: Date,
        usedFraction: Double? = nil,
        observedAt: Date,
        confidence: Confidence
    ) {
        self.provider = provider
        self.limitKind = limitKind ?? (duration <= 8 * 60 * 60 ? .session : .weekly)
        self.duration = duration
        self.resetsAt = resetsAt
        self.usedFraction = usedFraction
        self.observedAt = observedAt
        self.confidence = confidence
    }

    public func isOpen(at date: Date) -> Bool {
        date < resetsAt
    }

    /// How close to a full window `resetsAt` may sit before the window counts
    /// as not yet started. A window opened seconds ago also reads as full,
    /// so the tolerance is kept to little more than one polling interval.
    public static let unstartedTolerance: TimeInterval = 90

    /// True when the provider is describing a window that has not opened yet.
    ///
    /// Codex reports an idle limit as a full, unused window whose reset keeps
    /// pace with the clock: reset time minus reading time equals the window
    /// length. The moment a request lands the reset pins in place. That
    /// placeholder is what a wake request exists to replace, so it is named.
    public var isUnstarted: Bool {
        guard (usedFraction ?? 0) <= 0 else { return false }
        return resetsAt.timeIntervalSince(observedAt) >= duration - Self.unstartedTolerance
    }

    /// A window long enough to be a plan-level cap is not something a morning
    /// session can reopen, so it must not drive scheduling.
    public var isSessionWindow: Bool {
        limitKind == .session
    }
}
