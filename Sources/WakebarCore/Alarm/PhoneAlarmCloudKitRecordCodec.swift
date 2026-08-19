#if canImport(CloudKit)
import CloudKit
import Foundation

public struct PhoneAlarmCloudKitRecordCodec: Sendable {
    public static let payloadKey = "payloadData"
    public static let revisionSequenceKey = "revisionSequence"
    public static let modifiedAtKey = "modifiedAt"
    public static let writerIDKey = "writerID"

    public init() {}

    public func encode(
        _ cloudRecord: PhoneAlarmCloudRecord,
        zoneID: CKRecordZone.ID
    ) -> CKRecord {
        let recordID = CKRecord.ID(recordName: cloudRecord.recordName, zoneID: zoneID)
        let record = CKRecord(recordType: PhoneAlarmCloudRecord.recordType, recordID: recordID)
        apply(cloudRecord, to: record)
        return record
    }

    public func apply(_ cloudRecord: PhoneAlarmCloudRecord, to record: CKRecord) {
        record[Self.payloadKey] = cloudRecord.payloadData as CKRecordValue
        record[Self.revisionSequenceKey] = cloudRecord.revisionSequence as CKRecordValue
        record[Self.modifiedAtKey] = cloudRecord.modifiedAt as CKRecordValue
        record[Self.writerIDKey] = cloudRecord.writerID as CKRecordValue
    }

    public func decode(_ record: CKRecord) throws -> PhoneAlarmCloudRecord {
        guard record.recordType == PhoneAlarmCloudRecord.recordType,
              let payloadData = record[Self.payloadKey] as? Data,
              let sequence = record[Self.revisionSequenceKey] as? NSNumber,
              let modifiedAt = record[Self.modifiedAtKey] as? Date,
              let writerID = record[Self.writerIDKey] as? String
        else {
            throw CloudKitPhoneScheduleRepositoryError.malformedRecord
        }

        return PhoneAlarmCloudRecord(
            recordName: record.recordID.recordName,
            revisionSequence: sequence.int64Value,
            modifiedAt: modifiedAt,
            writerID: writerID,
            payloadData: payloadData
        )
    }
}
#endif
