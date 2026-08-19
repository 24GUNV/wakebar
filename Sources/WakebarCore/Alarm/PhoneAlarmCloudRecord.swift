import Foundation

public struct PhoneAlarmCloudRecord: Codable, Equatable, Sendable {
    public static let recordType = "WakeSchedule"
    public static let zoneName = "WakebarSchedules"
    public static let activeRecordName = "active-schedule"

    public let recordName: String
    public let revisionSequence: Int64
    public let modifiedAt: Date
    public let writerID: String
    public let payloadData: Data

    public init(
        recordName: String,
        revisionSequence: Int64,
        modifiedAt: Date,
        writerID: String,
        payloadData: Data
    ) {
        self.recordName = recordName
        self.revisionSequence = revisionSequence
        self.modifiedAt = modifiedAt
        self.writerID = writerID
        self.payloadData = payloadData
    }

    public init(payload: PhoneAlarmSchedulePayload, encoder: JSONEncoder = JSONEncoder()) throws {
        let validatedPayload = try payload.validated()
        recordName = Self.activeRecordName
        revisionSequence = validatedPayload.revision.sequence
        modifiedAt = validatedPayload.revision.modifiedAt
        writerID = validatedPayload.revision.writerID
        payloadData = try encoder.encode(validatedPayload)
    }

    public func payload(decoder: JSONDecoder = JSONDecoder()) throws -> PhoneAlarmSchedulePayload {
        let decoded = try decoder.decode(PhoneAlarmSchedulePayload.self, from: payloadData)
        let payload = try decoded.validated()
        guard recordName == Self.activeRecordName,
              revisionSequence == payload.revision.sequence,
              abs(modifiedAt.timeIntervalSince(payload.revision.modifiedAt)) < 0.001,
              writerID == payload.revision.writerID
        else {
            throw PhoneAlarmCloudRecordError.metadataMismatch
        }
        return payload
    }
}
