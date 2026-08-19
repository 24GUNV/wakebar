import Foundation

public struct PhoneAlarmSchedulePayload: Codable, Equatable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let scheduleID: UUID
    public let alarmID: UUID
    public let revision: PhoneScheduleRevision
    public let isEnabled: Bool
    public let title: String
    public let hour: Int
    public let minute: Int
    public let weekdays: Set<Weekday>
    public let followsDeviceTimeZone: Bool
    public let sourceTimeZoneIdentifier: String

    public var id: UUID { scheduleID }

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        scheduleID: UUID,
        alarmID: UUID,
        revision: PhoneScheduleRevision,
        isEnabled: Bool,
        title: String,
        hour: Int,
        minute: Int,
        weekdays: Set<Weekday>,
        followsDeviceTimeZone: Bool,
        sourceTimeZoneIdentifier: String
    ) {
        self.schemaVersion = schemaVersion
        self.scheduleID = scheduleID
        self.alarmID = alarmID
        self.revision = revision
        self.isEnabled = isEnabled
        self.title = title
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.followsDeviceTimeZone = followsDeviceTimeZone
        self.sourceTimeZoneIdentifier = sourceTimeZoneIdentifier
    }

    public func validated() throws -> Self {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw PhoneAlarmScheduleValidationError.unsupportedSchema(schemaVersion)
        }
        guard (0...23).contains(hour) else {
            throw PhoneAlarmScheduleValidationError.invalidHour(hour)
        }
        guard (0...59).contains(minute) else {
            throw PhoneAlarmScheduleValidationError.invalidMinute(minute)
        }
        guard !isEnabled || !weekdays.isEmpty else {
            throw PhoneAlarmScheduleValidationError.noWeekdays
        }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PhoneAlarmScheduleValidationError.emptyTitle
        }
        guard TimeZone(identifier: sourceTimeZoneIdentifier) != nil else {
            throw PhoneAlarmScheduleValidationError.invalidTimeZone(sourceTimeZoneIdentifier)
        }
        guard !isEnabled || followsDeviceTimeZone else {
            throw PhoneAlarmScheduleValidationError.fixedTimeZoneUnsupported
        }
        guard revision.sequence >= 0, !revision.writerID.isEmpty else {
            throw PhoneAlarmScheduleValidationError.invalidRevision
        }
        guard alarmID == scheduleID else {
            throw PhoneAlarmScheduleValidationError.alarmIDMustMatchSchedule
        }

        return self
    }

    public func shouldReplace(_ other: Self) -> Bool {
        guard revision.writerID == other.revision.writerID else {
            // A new writer can take ownership after it reads the current server record.
            return true
        }
        return revision.isNewer(than: other.revision)
    }
}
