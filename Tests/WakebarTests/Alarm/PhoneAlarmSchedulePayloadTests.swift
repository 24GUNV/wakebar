import Foundation
import XCTest
@testable import WakebarCore

final class PhoneAlarmSchedulePayloadTests: XCTestCase {
    func testCloudRecordRoundTripsValidatedPayload() throws {
        let payload = makePhoneAlarmPayload()

        let record = try PhoneAlarmCloudRecord(payload: payload)

        XCTAssertEqual(record.recordName, PhoneAlarmCloudRecord.activeRecordName)
        XCTAssertEqual(record.revisionSequence, 4)
        XCTAssertEqual(try record.payload(), payload)
    }

    func testPayloadRejectsMissingWeekdays() {
        let payload = makePhoneAlarmPayload(weekdays: [])

        XCTAssertThrowsError(try payload.validated()) { error in
            XCTAssertEqual(error as? PhoneAlarmScheduleValidationError, .noWeekdays)
        }
    }

    func testDisabledPayloadAllowsMissingWeekdaysForSafetyCancellation() throws {
        let payload = makePhoneAlarmPayload(isEnabled: false, weekdays: [])

        XCTAssertEqual(try payload.validated(), payload)
    }

    func testRevisionUsesStableTieBreakOrder() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let first = PhoneScheduleRevision(sequence: 3, modifiedAt: date, writerID: "mac-a")
        let second = PhoneScheduleRevision(sequence: 3, modifiedAt: date, writerID: "mac-b")

        XCTAssertTrue(second.isNewer(than: first))
        XCTAssertFalse(first.isNewer(than: second))
    }

    func testCloudRecordRejectsRevisionMetadataMismatch() throws {
        let payload = makePhoneAlarmPayload()
        let validRecord = try PhoneAlarmCloudRecord(payload: payload)
        let changedRecord = PhoneAlarmCloudRecord(
            recordName: validRecord.recordName,
            revisionSequence: validRecord.revisionSequence + 1,
            modifiedAt: validRecord.modifiedAt,
            writerID: validRecord.writerID,
            payloadData: validRecord.payloadData
        )

        XCTAssertThrowsError(try changedRecord.payload()) { error in
            XCTAssertEqual(error as? PhoneAlarmCloudRecordError, .metadataMismatch)
        }
    }

    func testDifferentWriterCanTakeOwnershipWithConditionalSave() {
        let oldSchedule = makePhoneAlarmPayload()
        let newID = testUUID("00000000-0000-0000-0000-000000000011")
        let newSchedule = PhoneAlarmSchedulePayload(
            scheduleID: newID,
            alarmID: newID,
            revision: PhoneScheduleRevision(
                sequence: 0,
                modifiedAt: oldSchedule.revision.modifiedAt.addingTimeInterval(60),
                writerID: "new-mac"
            ),
            isEnabled: true,
            title: "Wake up",
            hour: 8,
            minute: 0,
            weekdays: Weekday.workweek,
            followsDeviceTimeZone: true,
            sourceTimeZoneIdentifier: "UTC"
        )

        XCTAssertTrue(newSchedule.shouldReplace(oldSchedule))
        XCTAssertTrue(oldSchedule.shouldReplace(newSchedule))
    }

    func testSameWriterUsesGlobalSequenceAcrossScheduleIdentities() {
        let oldSchedule = makePhoneAlarmPayload()
        let newID = testUUID("00000000-0000-0000-0000-000000000012")
        let staleSchedule = PhoneAlarmSchedulePayload(
            scheduleID: newID,
            alarmID: newID,
            revision: PhoneScheduleRevision(
                sequence: oldSchedule.revision.sequence - 1,
                modifiedAt: oldSchedule.revision.modifiedAt.addingTimeInterval(60),
                writerID: oldSchedule.revision.writerID
            ),
            isEnabled: true,
            title: "Wake up",
            hour: 8,
            minute: 0,
            weekdays: Weekday.workweek,
            followsDeviceTimeZone: true,
            sourceTimeZoneIdentifier: "UTC"
        )

        XCTAssertFalse(staleSchedule.shouldReplace(oldSchedule))
    }

    func testRevisionNormalizesSubMillisecondCloudKitDates() throws {
        let originalDate = Date(timeIntervalSince1970: 1_800_000_000.123_456)
        let revision = PhoneScheduleRevision(
            sequence: 9,
            modifiedAt: originalDate,
            writerID: "test-mac"
        )
        let identifier = testUUID("00000000-0000-0000-0000-000000000013")
        let payload = PhoneAlarmSchedulePayload(
            scheduleID: identifier,
            alarmID: identifier,
            revision: revision,
            isEnabled: true,
            title: "Wake up",
            hour: 7,
            minute: 0,
            weekdays: Weekday.workweek,
            followsDeviceTimeZone: true,
            sourceTimeZoneIdentifier: "UTC"
        )
        let record = try PhoneAlarmCloudRecord(payload: payload)
        let quantizedRecord = PhoneAlarmCloudRecord(
            recordName: record.recordName,
            revisionSequence: record.revisionSequence,
            modifiedAt: Date(
                timeIntervalSince1970: (record.modifiedAt.timeIntervalSince1970 * 1_000).rounded()
                    / 1_000
            ),
            writerID: record.writerID,
            payloadData: record.payloadData
        )

        XCTAssertEqual(revision.modifiedAt, quantizedRecord.modifiedAt)
        XCTAssertEqual(try quantizedRecord.payload(), payload)
    }
}

private func makePhoneAlarmPayload(
    isEnabled: Bool = true,
    weekdays: Set<Weekday> = Weekday.workweek
) -> PhoneAlarmSchedulePayload {
    PhoneAlarmSchedulePayload(
        scheduleID: testUUID("00000000-0000-0000-0000-000000000010"),
        alarmID: testUUID("00000000-0000-0000-0000-000000000010"),
        revision: PhoneScheduleRevision(
            sequence: 4,
            modifiedAt: Date(timeIntervalSince1970: 1_800_000_000),
            writerID: "test-mac"
        ),
        isEnabled: isEnabled,
        title: "Wake up",
        hour: 7,
        minute: 0,
        weekdays: weekdays,
        followsDeviceTimeZone: true,
        sourceTimeZoneIdentifier: "UTC"
    )
}

private func testUUID(_ value: String) -> UUID {
    guard let identifier = UUID(uuidString: value) else {
        fatalError("Invalid test UUID: \(value)")
    }
    return identifier
}
