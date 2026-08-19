import Foundation
import XCTest
@testable import WakebarCore

final class PhoneAlarmAcknowledgementTests: XCTestCase {
    func testSameRevisionDoesNotWriteAnotherConfirmation() throws {
        let identifier = try XCTUnwrap(
            UUID(uuidString: "00000000-0000-0000-0000-000000000060")
        )
        let revision = PhoneScheduleRevision(
            sequence: 4,
            modifiedAt: Date(timeIntervalSince1970: 1_800_000_000),
            writerID: "test-mac"
        )
        let first = PhoneAlarmAcknowledgement(
            scheduleID: identifier,
            alarmID: identifier,
            revision: revision,
            confirmedAt: Date(timeIntervalSince1970: 1_800_000_010)
        )
        let laterAttempt = PhoneAlarmAcknowledgement(
            scheduleID: identifier,
            alarmID: identifier,
            revision: revision,
            confirmedAt: Date(timeIntervalSince1970: 1_800_000_020)
        )

        XCTAssertFalse(laterAttempt.shouldReplace(first))
    }
}
