import Foundation
import XCTest
@testable import WakebarCore

final class ProviderExecutionCoordinatorTests: XCTestCase {
    func testSuccessfulTriggerIsConfirmedAndDeduplicated() async throws {
        let ledger = ExecutionLedger(fileURL: temporaryLedgerURL())
        let coordinator = ProviderExecutionCoordinator(ledger: ledger)
        let event = makeEvent()

        let firstResult = try await coordinator.execute(
            event: event,
            using: SuccessfulProviderAdapter(id: .claude)
        )
        let secondResult = try await coordinator.execute(
            event: event,
            using: SuccessfulProviderAdapter(id: .claude)
        )

        guard case .confirmed = firstResult else {
            return XCTFail("Expected a confirmed execution")
        }
        guard case let .skippedDuplicate(record) = secondResult else {
            return XCTFail("Expected duplicate suppression")
        }
        XCTAssertEqual(record.state, .confirmed)
    }

    func testUncertainFailureRequiresManualReconciliation() async throws {
        let ledger = ExecutionLedger(fileURL: temporaryLedgerURL())
        let coordinator = ProviderExecutionCoordinator(ledger: ledger)
        let event = makeEvent()

        let result = try await coordinator.execute(
            event: event,
            using: IndeterminateProviderAdapter(id: .claude)
        )

        guard case .deliveryUnknown = result else {
            return XCTFail("Expected an unknown-delivery result")
        }
        XCTAssertEqual(try await ledger.record(for: event.id)?.state, .deliveryUnknown)
        XCTAssertFalse(try await ledger.resetFailedBeforeSendForRetry(eventID: event.id))
    }

    func testUnconfiguredAdapterCanBeResetForRetry() async throws {
        let ledger = ExecutionLedger(fileURL: temporaryLedgerURL())
        let coordinator = ProviderExecutionCoordinator(ledger: ledger)
        let event = makeEvent()

        let result = try await coordinator.execute(
            event: event,
            using: DryRunProviderAdapter(id: .claude)
        )

        guard case .failedBeforeSend = result else {
            return XCTFail("Expected a failure before send")
        }
        XCTAssertTrue(try await ledger.resetFailedBeforeSendForRetry(eventID: event.id))
    }

    private func makeEvent() -> ScheduledEvent {
        ScheduledEvent(
            scheduleID: UUID(),
            date: .now,
            wakeDate: .now.addingTimeInterval(600),
            kind: .providerSession(.claude, phase: .initial)
        )
    }

    private func temporaryLedgerURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "ledger.json")
    }
}
