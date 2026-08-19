import Foundation
import XCTest
@testable import WakebarCore

final class ExecutionLedgerTests: XCTestCase {
    func testRefusesDuplicateEventClaimsAcrossInstances() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "ledger.json")
        let firstLedger = ExecutionLedger(fileURL: fileURL)

        XCTAssertTrue(try await firstLedger.claim(eventID: "event-1"))
        XCTAssertFalse(try await firstLedger.claim(eventID: "event-1"))

        let reloadedLedger = ExecutionLedger(fileURL: fileURL)
        XCTAssertTrue(try await reloadedLedger.contains(eventID: "event-1"))
        XCTAssertEqual(try await reloadedLedger.record(for: "event-1")?.state, .claimed)
    }

    func testRemovesOnlyExpiredRecords() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let ledger = ExecutionLedger(fileURL: directory.appending(path: "ledger.json"))
        let now = Date.now

        XCTAssertTrue(try await ledger.claim(eventID: "old", at: now.addingTimeInterval(-100)))
        XCTAssertTrue(try await ledger.claim(eventID: "new", at: now))

        try await ledger.removeRecords(before: now.addingTimeInterval(-50))

        XCTAssertFalse(try await ledger.contains(eventID: "old"))
        XCTAssertTrue(try await ledger.contains(eventID: "new"))
    }

    func testTracksConfirmedAndUnknownDeliverySeparately() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let ledger = ExecutionLedger(fileURL: directory.appending(path: "ledger.json"))

        XCTAssertTrue(try await ledger.claim(eventID: "confirmed"))
        try await ledger.markConfirmed(eventID: "confirmed")
        XCTAssertEqual(try await ledger.record(for: "confirmed")?.state, .confirmed)

        XCTAssertTrue(try await ledger.claim(eventID: "unknown"))
        try await ledger.markDeliveryUnknown(eventID: "unknown")
        XCTAssertEqual(try await ledger.record(for: "unknown")?.state, .deliveryUnknown)
        XCTAssertFalse(try await ledger.resetFailedBeforeSendForRetry(eventID: "unknown"))
    }

    func testOnlyFailureBeforeSendCanBeResetForRetry() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let ledger = ExecutionLedger(fileURL: directory.appending(path: "ledger.json"))

        XCTAssertTrue(try await ledger.claim(eventID: "retryable"))
        try await ledger.markFailedBeforeSend(eventID: "retryable")
        XCTAssertTrue(try await ledger.resetFailedBeforeSendForRetry(eventID: "retryable"))
        XCTAssertFalse(try await ledger.contains(eventID: "retryable"))
        XCTAssertTrue(try await ledger.claim(eventID: "retryable"))
    }
}
