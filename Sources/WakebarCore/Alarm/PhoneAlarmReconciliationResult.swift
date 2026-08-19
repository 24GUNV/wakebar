public enum PhoneAlarmReconciliationResult: Equatable, Sendable {
    case inactive
    case permissionRequired
    case permissionDenied
    case unavailable(String)
    case updateRequired(previouslyInstalled: Bool)
    case alarmMissing
    case scheduled
}
