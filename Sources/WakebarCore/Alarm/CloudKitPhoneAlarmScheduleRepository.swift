#if canImport(CloudKit)
import CloudKit
import Foundation

public actor CloudKitPhoneAlarmScheduleRepository: PhoneAlarmScheduleRepository {
    public static let containerIdentifier = "iCloud.com.24gunv.wakebar"
    public static let subscriptionID = "wakebar-phone-schedule-changes-v2"
    private static let legacySubscriptionIDs: Set<CKSubscription.ID> = [
        "wakebar-phone-schedule-changes"
    ]

    private let container: CKContainer
    private let database: CKDatabase
    private let cache: PhoneAlarmPayloadStore
    private let codec = PhoneAlarmCloudKitRecordCodec()
    private let zoneID = CKRecordZone.ID(
        zoneName: PhoneAlarmCloudRecord.zoneName,
        ownerName: CKCurrentUserDefaultName
    )

    public init(
        container: CKContainer = CKContainer(
            identifier: CloudKitPhoneAlarmScheduleRepository.containerIdentifier
        ),
        cache: PhoneAlarmPayloadStore = PhoneAlarmPayloadStore()
    ) {
        self.container = container
        database = container.privateCloudDatabase
        self.cache = cache
    }

    public func fetchLatest() async -> PhoneScheduleDeliveryState {
        let checkedAt = Date.now
        var accountRecordName: String?

        do {
            let currentAccountRecordName = try await requireAvailableAccount()
            accountRecordName = currentAccountRecordName
            try await ensureZone()
            let payload = try await fetchNewestPayload()
            if let payload {
                try await cache.save(
                    CachedPhoneAlarmSchedule(
                        payload: payload,
                        lastSuccessfulSync: checkedAt,
                        accountRecordName: currentAccountRecordName
                    )
                )
                return .current(payload, checkedAt: checkedAt)
            }
            try await cache.clear()
            return .noSchedule(checkedAt: checkedAt)
        } catch {
            let reason = error.localizedDescription
            if let repositoryError = error as? CloudKitPhoneScheduleRepositoryError {
                switch repositoryError {
                case .noAccount, .restricted:
                    try? await cache.clear()
                    return .accountChanged(reason: reason, checkedAt: checkedAt)
                case .accountStatusUnavailable, .temporarilyUnavailable, .malformedRecord,
                     .concurrentWriterConflict:
                    break
                }
            }
            if let accountRecordName,
               let cachedSchedule = try? await cache.load(),
               cachedSchedule.accountRecordName == accountRecordName
            {
                return .stale(
                    cachedSchedule.payload,
                    lastSuccessfulSync: cachedSchedule.lastSuccessfulSync,
                    reason: reason
                )
            }
            if let accountRecordName,
               let cachedSchedule = try? await cache.load(),
               cachedSchedule.accountRecordName != accountRecordName
            {
                try? await cache.clear()
                return .accountChanged(
                    reason: "The iCloud account changed. Publish a Wakebar schedule for this account.",
                    checkedAt: checkedAt
                )
            }
            return .unavailable(reason: reason, checkedAt: checkedAt)
        }
    }

    public func installChangeSubscription() async -> PhoneScheduleSubscriptionState {
        do {
            _ = try await requireAvailableAccount()
            try await ensureZone()
            let subscriptions = try await database.allSubscriptions()
            var hasCurrentSubscription = false
            for subscription in subscriptions {
                let isLegacy = Self.legacySubscriptionIDs.contains(subscription.subscriptionID)
                let isCurrentID = subscription.subscriptionID == Self.subscriptionID
                let zoneSubscription = subscription as? CKRecordZoneSubscription
                let isCorrectCurrentSubscription = isCurrentID
                    && zoneSubscription?.zoneID == zoneID
                    && zoneSubscription?.recordType == PhoneAlarmCloudRecord.recordType

                if isCorrectCurrentSubscription {
                    hasCurrentSubscription = true
                } else if isLegacy || isCurrentID {
                    _ = try await database.deleteSubscription(withID: subscription.subscriptionID)
                }
            }

            guard !hasCurrentSubscription else { return .installed }
            let subscription = CKRecordZoneSubscription(
                zoneID: zoneID,
                subscriptionID: Self.subscriptionID
            )
            subscription.recordType = PhoneAlarmCloudRecord.recordType
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true
            subscription.notificationInfo = notificationInfo
            _ = try await database.save(subscription)
            return .installed
        } catch {
            return .unavailable(error.localizedDescription)
        }
    }

    public func publish(_ payload: PhoneAlarmSchedulePayload) async throws {
        let payload = try payload.validated()
        _ = try await requireAvailableAccount()
        try await ensureZone()
        try await publish(payload, remainingConflictRetries: 3)
    }

    private func publish(
        _ payload: PhoneAlarmSchedulePayload,
        remainingConflictRetries: Int
    ) async throws {
        let cloudRecord = try PhoneAlarmCloudRecord(payload: payload)
        let recordID = CKRecord.ID(recordName: cloudRecord.recordName, zoneID: zoneID)
        let record: CKRecord
        var isWriterTakeover = false

        do {
            let existingRecord = try await database.record(for: recordID)
            let existingPayload = try codec.decode(existingRecord).payload()
            guard payload.shouldReplace(existingPayload) else { return }
            isWriterTakeover = payload.revision.writerID != existingPayload.revision.writerID
            codec.apply(cloudRecord, to: existingRecord)
            record = existingRecord
        } catch let error as CKError where error.code == .unknownItem {
            record = codec.encode(cloudRecord, zoneID: zoneID)
        }

        do {
            try await saveIfServerRecordUnchanged(record)
        } catch let error as CKError
            where error.code == .serverRecordChanged
        {
            guard !isWriterTakeover else {
                throw CloudKitPhoneScheduleRepositoryError.concurrentWriterConflict
            }
            guard remainingConflictRetries > 0 else { throw error }
            try await publish(payload, remainingConflictRetries: remainingConflictRetries - 1)
        }
    }

    public func acknowledge(_ acknowledgement: PhoneAlarmAcknowledgement) async throws {
        _ = try await requireAvailableAccount()
        try await ensureZone()
        try await acknowledge(acknowledgement, remainingConflictRetries: 3)
    }

    private func acknowledge(
        _ acknowledgement: PhoneAlarmAcknowledgement,
        remainingConflictRetries: Int
    ) async throws {
        let recordID = CKRecord.ID(recordName: acknowledgement.recordName, zoneID: zoneID)
        let record: CKRecord
        var isWriterTakeover = false

        do {
            let existingRecord = try await database.record(for: recordID)
            let existingAcknowledgement = try decodeAcknowledgement(existingRecord)
            isWriterTakeover = existingAcknowledgement.revision.writerID
                != acknowledgement.revision.writerID
            guard acknowledgement.shouldReplace(existingAcknowledgement) else { return }
            record = existingRecord
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(
                recordType: PhoneAlarmAcknowledgement.recordType,
                recordID: recordID
            )
        }
        apply(acknowledgement, to: record)

        do {
            try await saveIfServerRecordUnchanged(record)
        } catch let error as CKError
            where error.code == .serverRecordChanged
        {
            guard !isWriterTakeover else {
                throw CloudKitPhoneScheduleRepositoryError.concurrentWriterConflict
            }
            guard remainingConflictRetries > 0 else { throw error }
            try await acknowledge(
                acknowledgement,
                remainingConflictRetries: remainingConflictRetries - 1
            )
        }
    }

    public func acknowledgement(for scheduleID: UUID) async throws -> PhoneAlarmAcknowledgement? {
        _ = try await requireAvailableAccount()
        let recordName = "ack-\(scheduleID.uuidString.lowercased())"
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)

        do {
            let record = try await database.record(for: recordID)
            return try decodeAcknowledgement(record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func requireAvailableAccount() async throws -> String {
        switch try await container.accountStatus() {
        case .available:
            return try await container.userRecordID().recordName
        case .noAccount:
            throw CloudKitPhoneScheduleRepositoryError.noAccount
        case .restricted:
            throw CloudKitPhoneScheduleRepositoryError.restricted
        case .couldNotDetermine:
            throw CloudKitPhoneScheduleRepositoryError.accountStatusUnavailable
        case .temporarilyUnavailable:
            throw CloudKitPhoneScheduleRepositoryError.temporarilyUnavailable
        @unknown default:
            throw CloudKitPhoneScheduleRepositoryError.accountStatusUnavailable
        }
    }

    private func ensureZone() async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        let result = try await database.modifyRecordZones(saving: [zone], deleting: [])
        guard let saveResult = result.saveResults[zoneID] else {
            throw CloudKitPhoneScheduleRepositoryError.accountStatusUnavailable
        }
        _ = try saveResult.get()
    }

    private func fetchNewestPayload() async throws -> PhoneAlarmSchedulePayload? {
        let recordID = CKRecord.ID(
            recordName: PhoneAlarmCloudRecord.activeRecordName,
            zoneID: zoneID
        )
        do {
            let record = try await database.record(for: recordID)
            return try codec.decode(record).payload()
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private func saveIfServerRecordUnchanged(_ record: CKRecord) async throws {
        let response = try await database.modifyRecords(
            saving: [record],
            deleting: [],
            savePolicy: .ifServerRecordUnchanged,
            atomically: true
        )
        guard let result = response.saveResults[record.recordID] else {
            throw CloudKitPhoneScheduleRepositoryError.malformedRecord
        }
        _ = try result.get()
    }

    private func apply(
        _ acknowledgement: PhoneAlarmAcknowledgement,
        to record: CKRecord
    ) {
        record["scheduleID"] = acknowledgement.scheduleID.uuidString as CKRecordValue
        record["alarmID"] = acknowledgement.alarmID.uuidString as CKRecordValue
        record["revisionSequence"] = acknowledgement.revision.sequence as CKRecordValue
        record["revisionModifiedAt"] = acknowledgement.revision.modifiedAt as CKRecordValue
        record["writerID"] = acknowledgement.revision.writerID as CKRecordValue
        record["confirmedAt"] = acknowledgement.confirmedAt as CKRecordValue
    }

    private func decodeAcknowledgement(_ record: CKRecord) throws -> PhoneAlarmAcknowledgement {
        guard record.recordType == PhoneAlarmAcknowledgement.recordType,
              let scheduleIDText = record["scheduleID"] as? String,
              let scheduleID = UUID(uuidString: scheduleIDText),
              let alarmIDText = record["alarmID"] as? String,
              let alarmID = UUID(uuidString: alarmIDText),
              let sequence = record["revisionSequence"] as? NSNumber,
              let revisionModifiedAt = record["revisionModifiedAt"] as? Date,
              let writerID = record["writerID"] as? String,
              let confirmedAt = record["confirmedAt"] as? Date
        else {
            throw CloudKitPhoneScheduleRepositoryError.malformedRecord
        }

        return PhoneAlarmAcknowledgement(
            scheduleID: scheduleID,
            alarmID: alarmID,
            revision: PhoneScheduleRevision(
                sequence: sequence.int64Value,
                modifiedAt: revisionModifiedAt,
                writerID: writerID
            ),
            confirmedAt: confirmedAt
        )
    }
}
#endif
