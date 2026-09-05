import Foundation
import WakebarCore

enum ProviderStartNowOutcome: Equatable, Sendable {
    /// The provider confirmed a new usage window; this is that window as the
    /// provider reported it, so its start is `resetsAt - duration` rather
    /// than the moment the poll happened to notice.
    case started(UsageWindow)
    case unconfirmed
}
