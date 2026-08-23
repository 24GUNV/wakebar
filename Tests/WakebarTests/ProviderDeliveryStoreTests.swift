import Foundation
import XCTest
@testable import WakebarCore

final class ProviderDeliveryStoreTests: XCTestCase {
    func testConfirmedStateSurvivesRelaunchForSameRevision() async throws {
        let store = ProviderDeliveryStore(fileURL: temporaryStoreURL())
        let revision = UUID()
        var states = try await store.load(for: revision)
        states[.claude] = ProviderDeliveryState(
            provider: .claude,
            desiredRevision: revision,
            appliedRevision: revision,
            phase: .confirmed,
            lastConfirmedAt: .now,
            detail: "Confirmed manually"
        )
        try await store.save(states)

        let reloaded = try await store.load(for: revision)

        XCTAssertTrue(reloaded[.claude]?.isCurrentRevisionConfirmed == true)
        XCTAssertEqual(reloaded[.codex]?.phase, .draft)
    }

    func testNewScheduleRevisionInvalidatesOldConfirmation() async throws {
        let store = ProviderDeliveryStore(fileURL: temporaryStoreURL())
        let oldRevision = UUID()
        var states = try await store.load(for: oldRevision)
        states[.claude] = ProviderDeliveryState(
            provider: .claude,
            desiredRevision: oldRevision,
            appliedRevision: oldRevision,
            phase: .confirmed
        )
        try await store.save(states)

        let reloaded = try await store.load(for: UUID())

        XCTAssertEqual(reloaded[.claude]?.phase, .draft)
        XCTAssertFalse(reloaded[.claude]?.isCurrentRevisionConfirmed == true)
    }

    func testConfirmationSurvivesRelaunchWhenStorePathContainsSpaces() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Wakebar Delivery \(UUID())", directoryHint: .isDirectory)
        let storeURL = directory.appending(path: "delivery.json")
        let revision = UUID()
        let store = ProviderDeliveryStore(fileURL: storeURL)
        var states = try await store.load(for: revision)
        states[.claude] = ProviderDeliveryState(
            provider: .claude,
            desiredRevision: revision,
            appliedRevision: revision,
            phase: .confirmed
        )
        try await store.save(states)

        let reloaded = try await ProviderDeliveryStore(fileURL: storeURL).load(for: revision)

        XCTAssertTrue(reloaded[.claude]?.isCurrentRevisionConfirmed == true)
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "delivery.json")
    }
}
