import Foundation
import WakebarCore

/// One usage window, ready to be read out as a row.
///
/// Both kinds of window earn a row. Only a session window can drive the
/// schedule, but a weekly cap is the only usage figure Codex publishes on a day
/// when no session window is open — and a provider showing nothing at all reads
/// as "Wakebar cannot see this", which is a different and wrong claim.
struct UsageWindowRow: Identifiable, Equatable {
    let provider: ProviderID
    /// False for a plan-level cap, which resets days out rather than hours.
    let isSessionWindow: Bool
    let resetsAt: Date
    let usedFraction: Double?
    /// Reconstructed rather than reported, so the time is shown as approximate.
    let isEstimate: Bool

    var id: String { "\(provider.rawValue)-\(isSessionWindow)" }

    init(_ window: UsageWindow) {
        provider = window.provider
        isSessionWindow = window.isSessionWindow
        resetsAt = window.resetsAt
        usedFraction = window.usedFraction
        isEstimate = window.confidence == .inferred
    }

    /// Says which limit this is, because "Codex resets" beside a date six days
    /// out would otherwise read as a broken session window.
    var label: String {
        isSessionWindow ? "\(provider.displayName) resets" : "\(provider.displayName) weekly"
    }
}
