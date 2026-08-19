public enum PhoneAlarmAuthorizationState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case unavailable(String)

    public var canSchedule: Bool {
        self == .authorized
    }
}
