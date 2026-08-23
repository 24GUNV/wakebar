import Foundation
import XCTest
@testable import WakebarCore

final class ExecutionLedgerTests: XCTestCase {
    func testRefusesDuplicateEventClaimsAcrossInstances() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "ledger.json")
        let firstLedger = ExecutionLedger(fileURL: fileURL)

        let firstClaim = try await firstLedger.claim(eventID: "event-1")
        let duplicateClaim = try await firstLedger.claim(eventID: "event-1")
        XCTAssertTrue(firstClaim)
        XCTAssertFalse(duplicateClaim)

        let reloadedLedger = ExecutionLedger(fileURL: fileURL)
        let containsEvent = try await reloadedLedger.contains(eventID: "event-1")
        let record = try await reloadedLedger.record(for: "event-1")
        XCTAssertTrue(containsEvent)
        XCTAssertEqual(record?.state, .claimed)
    }

    func testRemovesOnlyExpiredRecords() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let ledger = ExecutionLedger(fileURL: directory.appending(path: "ledger.json"))
        let now = Date.now

        let oldClaim = try await ledger.claim(eventID: "old", at: now.addingTimeInterval(-100))
        let newClaim = try await ledger.claim(eventID: "new", at: now)
        XCTAssertTrue(oldClaim)
        XCTAssertTrue(newClaim)

        try await ledger.removeRecords(before: now.addingTimeInterval(-50))

        let containsOld = try await ledger.contains(eventID: "old")
        let containsNew = try await ledger.contains(eventID: "new")
        XCTAssertFalse(containsOld)
        XCTAssertTrue(containsNew)
    }

    func testTracksConfirmedAndUnknownDeliverySeparately() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let ledger = ExecutionLedger(fileURL: directory.appending(path: "ledger.json"))

        let confirmedClaim = try await ledger.claim(eventID: "confirmed")
        XCTAssertTrue(confirmedClaim)
        try await ledger.markConfirmed(eventID: "confirmed")
        let confirmedRecord = try await ledger.record(for: "confirmed")
        XCTAssertEqual(confirmedRecord?.state, .confirmed)

        let unknownClaim = try await ledger.claim(eventID: "unknown")
        XCTAssertTrue(unknownClaim)
        try await ledger.markDeliveryUnknown(eventID: "unknown")
        let unknownRecord = try await ledger.record(for: "unknown")
        let didResetUnknown = try await ledger.resetFailedBeforeSendForRetry(eventID: "unknown")
        XCTAssertEqual(unknownRecord?.state, .deliveryUnknown)
        XCTAssertFalse(didResetUnknown)
    }

    func testOnlyFailureBeforeSendCanBeResetForRetry() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let ledger = ExecutionLedger(fileURL: directory.appending(path: "ledger.json"))

        let firstClaim = try await ledger.claim(eventID: "retryable")
        XCTAssertTrue(firstClaim)
        try await ledger.markFailedBeforeSend(eventID: "retryable")
        let didReset = try await ledger.resetFailedBeforeSendForRetry(eventID: "retryable")
        let containsAfterReset = try await ledger.contains(eventID: "retryable")
        let secondClaim = try await ledger.claim(eventID: "retryable")
        XCTAssertTrue(didReset)
        XCTAssertFalse(containsAfterReset)
        XCTAssertTrue(secondClaim)
    }

    func testClaimSurvivesRelaunchWhenLedgerPathContainsSpaces() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Wakebar Ledger \(UUID())", directoryHint: .isDirectory)
        let ledgerURL = directory.appending(path: "ledger.json")
        let firstLedger = ExecutionLedger(fileURL: ledgerURL)
        let didClaim = try await firstLedger.claim(eventID: "spaced-path")
        XCTAssertTrue(didClaim)

        let reloadedLedger = ExecutionLedger(fileURL: ledgerURL)
        let containsClaim = try await reloadedLedger.contains(eventID: "spaced-path")

        XCTAssertTrue(containsClaim)
    }
}
