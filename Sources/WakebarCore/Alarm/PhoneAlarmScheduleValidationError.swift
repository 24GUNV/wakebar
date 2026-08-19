import Foundation

public enum PhoneAlarmScheduleValidationError: LocalizedError, Equatable, Sendable {
    case unsupportedSchema(Int)
    case invalidHour(Int)
    case invalidMinute(Int)
    case noWeekdays
    case emptyTitle
    case invalidTimeZone(String)
    case fixedTimeZoneUnsupported
    case invalidRevision
    case alarmIDMustMatchSchedule

    public var errorDescription: String? {
        switch self {
        case let .unsupportedSchema(version):
            "Schedule format \(version) is not supported. Update Wakebar on this iPhone."
        case let .invalidHour(hour):
            "The synced hour \(hour) is invalid."
        case let .invalidMinute(minute):
            "The synced minute \(minute) is invalid."
        case .noWeekdays:
            "Choose at least one wake day on the Mac."
        case .emptyTitle:
            "The synced alarm title is empty."
        case let .invalidTimeZone(identifier):
            "The synced time zone \(identifier) is not available on this iPhone."
        case .fixedTimeZoneUnsupported:
            "This version can set alarms only in the iPhone’s local time zone."
        case .invalidRevision:
            "The synced schedule revision is invalid."
        case .alarmIDMustMatchSchedule:
            "The iPhone alarm identifier does not match the schedule identifier."
        }
    }
}
