import Foundation

public enum PhoneAlarmApplicationResult: Equatable, Sendable {
    case inactive
    case permissionRequired
    case permissionDenied
    case unavailable(String)
    case scheduled(alarmID: UUID, revision: PhoneScheduleRevision)
}
