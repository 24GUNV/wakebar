import Foundation

/// What decides when Wakebar opens the next session.
///
/// These are alternatives, not a switch and a modifier. A user either wants
/// their window kept open around the clock, or wants it open for a morning they
/// have named. Offering both at once produced a schedule with a repeat checkbox
/// bolted to it, which could not answer the only question the popover asks:
/// when does Wakebar next do something.
public enum SessionCadence: String, Codable, Sendable, CaseIterable, Identifiable {
    /// One session before each scheduled wake, optionally repeating to a cutoff.
    case schedule
    /// One session every time the usage window resets, indefinitely. The wake
    /// time still governs the alarm; it just no longer governs the sessions.
    case continuous

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .schedule: "Schedule"
        case .continuous: "Every reset"
        }
    }

    /// What the popover's hero is counting down to in this cadence.
    public var heroLabel: String {
        switch self {
        case .schedule: "Next wake"
        case .continuous: "Next session"
        }
    }
}
