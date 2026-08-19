public enum PhoneScheduleSubscriptionState: Equatable, Sendable {
    case notInstalled
    case installed
    case unavailable(String)
}
