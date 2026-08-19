import Foundation

public struct PhoneAlarmAcknowledgement: Equatable, Sendable {
    public static let recordType = "WakeScheduleAcknowledgement"

    public let scheduleID: UUID
    public let alarmID: UUID
    public let revision: PhoneScheduleRevision
    public let confirmedAt: Date

    public init(
        scheduleID: UUID,
        alarmID: UUID,
        revision: PhoneScheduleRevision,
        confirmedAt: Date
    ) {
        self.scheduleID = scheduleID
        self.alarmID = alarmID
        self.revision = revision
        self.confirmedAt = confirmedAt
    }

    public var recordName: String {
        "ack-\(scheduleID.uuidString.lowercased())"
    }

    public func shouldReplace(_ other: Self) -> Bool {
        guard revision.writerID == other.revision.writerID else { return true }
        return revision.isNewer(than: other.revision)
    }
}
