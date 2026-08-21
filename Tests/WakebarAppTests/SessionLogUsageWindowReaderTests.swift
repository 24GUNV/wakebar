import XCTest
@testable import Wakebar

final class SessionLogUsageWindowReaderTests: XCTestCase {
    /// The scan reads the field out of the raw bytes rather than decoding the
    /// line, so the shapes it has to survive are worth pinning down.
    func testReadsTimestampsFromLogBytes() throws {
        let log = """
        {"type":"mode","mode":"normal"}
        {"snapshot":{"timestamp":"2026-08-21T14:02:10.552Z"}}
        {"parentUuid":null,"timestamp":"2026-08-21T14:03:00Z","usage":{"input_tokens":10}}
        """
        let dates = SessionLogUsageWindowReader.timestamps(in: Data(log.utf8))

        XCTAssertEqual(dates.count, 2)
        XCTAssertEqual(
            dates[1].timeIntervalSince(dates[0]),
            49.448,
            accuracy: 0.01
        )
    }

    /// A key that merely ends in the same letters is not the field.
    func testIgnoresLookalikeKeys() {
        let log = #"{"lastTimestamp":"2026-08-21T14:02:10Z","snapshotTimestamp":"2026-08-21T15:00:00Z"}"#
        XCTAssertTrue(SessionLogUsageWindowReader.timestamps(in: Data(log.utf8)).isEmpty)
    }

    /// A log cut off mid-write must not take the read down with it.
    func testTruncatedValueIsDropped() {
        let log = #"{"timestamp":"2026-08-21T14:02:10Z"}{"timestamp":"2026-08-2"#
        XCTAssertEqual(SessionLogUsageWindowReader.timestamps(in: Data(log.utf8)).count, 1)
    }

    func testEmptyDataYieldsNothing() {
        XCTAssertTrue(SessionLogUsageWindowReader.timestamps(in: Data()).isEmpty)
    }
}
