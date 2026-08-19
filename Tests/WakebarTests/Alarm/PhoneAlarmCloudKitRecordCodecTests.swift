#if canImport(CloudKit)
import CloudKit
import Foundation
import XCTest
@testable import WakebarCore

final class PhoneAlarmCloudKitRecordCodecTests: XCTestCase {
    func testCloudKitRecordRoundTrips() throws {
        let identifier = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000050")
        )
        let payload = PhoneAlarmSchedulePayload(
            scheduleID: identifier,
            alarmID: identifier,
            revision: PhoneScheduleRevision(
                sequence: 9,
                modifiedAt: Date(timeIntervalSince1970: 1_800_000_000),
                writerID: "codec-test"
            ),
            isEnabled: true,
            title: "Wake up",
            hour: 7,
            minute: 0,
            weekdays: Weekday.workweek,
            followsDeviceTimeZone: true,
            sourceTimeZoneIdentifier: "UTC"
        )
        let cloudRecord = try PhoneAlarmCloudRecord(payload: payload)
        let codec = PhoneAlarmCloudKitRecordCodec()
        let zoneID = CKRecordZone.ID(
            zoneName: PhoneAlarmCloudRecord.zoneName,
            ownerName: CKCurrentUserDefaultName
        )

        let encoded = codec.encode(cloudRecord, zoneID: zoneID)
        let decoded = try codec.decode(encoded)

        XCTAssertEqual(decoded, cloudRecord)
        XCTAssertEqual(try decoded.payload(), payload)
    }
}
#endif
