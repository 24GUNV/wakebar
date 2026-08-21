/// The state a single service row reports.
///
/// Only `actionRequired` is allowed to take colour in the interface. Keeping
/// the good states quiet is what makes the one row that needs the user
/// readable at a glance.
public enum ServiceStatusKind: Equatable, Sendable {
    case ready
    case inProgress
    case actionRequired
}
