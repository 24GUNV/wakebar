import Foundation
import XCTest
@testable import WakebarCore

final class PhoneAlarmCoordinatorTests: XCTestCase {
    func testCoordinatorDoesNotPromptWithoutUserAction() async throws {
        let client = TestPhoneAlarmClient(authorization: .notDetermined)
        let coordinator = makeTestCoordinator(client: client)

        let result = try await coordinator.apply(
            makeCoordinatorPayload(),
            requestingAuthorization: false
        )
        let snapshot = await client.snapshot()

        XCTAssertEqual(result, .permissionRequired)
        XCTAssertEqual(snapshot.requestCount, 0)
        XCTAssertTrue(snapshot.scheduled.isEmpty)
    }

    func testExplicitUserActionRequestsPermissionAndSchedules() async throws {
        let client = TestPhoneAlarmClient(authorization: .notDetermined)
        let coordinator = makeTestCoordinator(client: client)
        let payload = makeCoordinatorPayload()

        let result = try await coordinator.apply(payload, requestingAuthorization: true)
        let snapshot = await client.snapshot()

        XCTAssertEqual(result, .scheduled(alarmID: payload.alarmID, revision: payload.revision))
        XCTAssertEqual(snapshot.requestCount, 1)
        XCTAssertEqual(snapshot.scheduled, [payload])
    }

    func testDisabledPayloadCancelsExistingAlarm() async throws {
        let client = TestPhoneAlarmClient(authorization: .authorized)
        let coordinator = makeTestCoordinator(client: client)
        let enabledPayload = makeCoordinatorPayload()
        let payload = makeCoordinatorPayload(revisionSequence: 2, isEnabled: false)
        _ = try await coordinator.apply(enabledPayload, requestingAuthorization: false)

        let result = try await coordinator.apply(payload, requestingAuthorization: false)
        let snapshot = await client.snapshot()
        let activeAlarmIDs = try await client.scheduledAlarmIDs()

        XCTAssertEqual(result, .inactive)
        XCTAssertEqual(snapshot.cancelled, [payload.alarmID])
        XCTAssertTrue(activeAlarmIDs.isEmpty)
    }

    func testReconciliationDetectsExternalAlarmRemoval() async throws {
        let client = TestPhoneAlarmClient(authorization: .authorized)
        let coordinator = makeTestCoordinator(client: client)
        let payload = makeCoordinatorPayload()
        _ = try await coordinator.apply(payload, requestingAuthorization: false)
        try await client.cancel(alarmID: payload.alarmID)

        let result = try await coordinator.reconcile(payload)

        XCTAssertEqual(result, .alarmMissing)
    }

    func testNewScheduleIdentityCancelsOldAlarm() async throws {
        let client = TestPhoneAlarmClient(authorization: .authorized)
        let coordinator = makeTestCoordinator(client: client)
        let first = makeCoordinatorPayload()
        let secondID = coordinatorTestUUID("00000000-0000-0000-0000-000000000031")
        let second = makeCoordinatorPayload(scheduleID: secondID, revisionSequence: 2)
        _ = try await coordinator.apply(first, requestingAuthorization: false)

        _ = try await coordinator.apply(second, requestingAuthorization: false)
        let snapshot = await client.snapshot()
        let activeAlarmIDs = try await client.scheduledAlarmIDs()

        XCTAssertTrue(snapshot.cancelled.contains(first.alarmID))
        XCTAssertEqual(activeAlarmIDs, [second.alarmID])
    }

    func testFailedReplacementRestoresPreviousAlarm() async throws {
        let client = TestPhoneAlarmClient(authorization: .authorized)
        let coordinator = makeTestCoordinator(client: client)
        let first = makeCoordinatorPayload()
        let second = makeCoordinatorPayload(revisionSequence: 2)
        _ = try await coordinator.apply(first, requestingAuthorization: false)
        await client.failNextSchedule()

        do {
            _ = try await coordinator.apply(second, requestingAuthorization: false)
            XCTFail("Expected the replacement schedule to fail")
        } catch TestPhoneAlarmClientError.scheduleFailed {
            // The original error is returned after Wakebar restores the prior alarm.
        }

        let activeAlarmIDs = try await client.scheduledAlarmIDs()
        let reconciliation = try await coordinator.reconcile(first)
        XCTAssertEqual(activeAlarmIDs, [first.alarmID])
        XCTAssertEqual(reconciliation, .scheduled)
    }

    func testFailedJournalSaveDoesNotChangePreviousAlarm() async throws {
        let client = TestPhoneAlarmClient(authorization: .authorized)
        let store = TestPhoneAlarmInstallationStore()
        let coordinator = PhoneAlarmCoordinator(client: client, installationStore: store)
        let first = makeCoordinatorPayload()
        let second = makeCoordinatorPayload(revisionSequence: 2)
        _ = try await coordinator.apply(first, requestingAuthorization: false)
        await store.failNextSave()

        do {
            _ = try await coordinator.apply(second, requestingAuthorization: false)
            XCTFail("Expected installation persistence to fail")
        } catch TestPhoneAlarmInstallationStoreError.saveFailed {
            // The original error is returned after Wakebar restores the prior alarm and record.
        }

        let activeAlarmIDs = try await client.scheduledAlarmIDs()
        let reconciliation = try await coordinator.reconcile(first)
        XCTAssertEqual(activeAlarmIDs, [first.alarmID])
        XCTAssertEqual(reconciliation, .scheduled)
    }

    func testFailedFinalInstallationSaveRestoresPreviousAlarm() async throws {
        let client = TestPhoneAlarmClient(authorization: .authorized)
        let store = TestPhoneAlarmInstallationStore()
        let coordinator = PhoneAlarmCoordinator(client: client, installationStore: store)
        let first = makeCoordinatorPayload()
        let second = makeCoordinatorPayload(revisionSequence: 2)
        _ = try await coordinator.apply(first, requestingAuthorization: false)
        await store.failSave(onAdditionalAttempts: [2])

        do {
            _ = try await coordinator.apply(second, requestingAuthorization: false)
            XCTFail("Expected final installation persistence to fail")
        } catch TestPhoneAlarmInstallationStoreError.saveFailed {
            // The final save fails after AlarmKit accepts the new revision.
        }

        let activeAlarmIDs = try await client.scheduledAlarmIDs()
        let reconciliation = try await coordinator.reconcile(first)
        XCTAssertEqual(activeAlarmIDs, [first.alarmID])
        XCTAssertEqual(reconciliation, .scheduled)
    }

    func testRestoreSaveFailureLeavesRetryableJournal() async throws {
        let client = TestPhoneAlarmClient(authorization: .authorized)
        let store = TestPhoneAlarmInstallationStore()
        let coordinator = PhoneAlarmCoordinator(client: client, installationStore: store)
        let first = makeCoordinatorPayload()
        let second = makeCoordinatorPayload(revisionSequence: 2)
        _ = try await coordinator.apply(first, requestingAuthorization: false)
        await store.failSave(onAdditionalAttempts: [2, 3])

        do {
            _ = try await coordinator.apply(second, requestingAuthorization: false)
            XCTFail("Expected replacement recovery persistence to fail")
        } catch PhoneAlarmCoordinatorError.replacementAndRestoreFailed {
            // The old alarm is active and the pre-change journal remains for a retry.
        }

        let activeAlarmIDs = try await client.scheduledAlarmIDs()
        let journal = try await store.load()
        XCTAssertEqual(activeAlarmIDs, [first.alarmID])
        XCTAssertEqual(journal?.payload, second)
        XCTAssertEqual(journal?.recoveryPayload, first)
        XCTAssertEqual(journal?.requiresReconciliation, true)
    }

    func testCancellationFailurePreservesRecoveryState() async throws {
        let client = TestPhoneAlarmClient(authorization: .authorized)
        let store = TestPhoneAlarmInstallationStore()
        let coordinator = PhoneAlarmCoordinator(client: client, installationStore: store)
        let first = makeCoordinatorPayload()
        let secondID = coordinatorTestUUID("00000000-0000-0000-0000-000000000032")
        let second = makeCoordinatorPayload(scheduleID: secondID, revisionSequence: 2)
        _ = try await coordinator.apply(first, requestingAuthorization: false)
        await client.failNextCancellation()

        do {
            _ = try await coordinator.apply(second, requestingAuthorization: false)
            XCTFail("Expected cancellation to fail")
        } catch PhoneAlarmCoordinatorError.cancellationFailed {
            // Wakebar keeps the prior alarm and a retryable recovery record.
        }

        let activeAlarmIDs = try await client.scheduledAlarmIDs()
        let installation = try await store.load()
        XCTAssertEqual(activeAlarmIDs, [first.alarmID])
        XCTAssertEqual(installation?.payload, first)
        XCTAssertEqual(installation?.recoveryPayload, first)
        XCTAssertEqual(installation?.requiresReconciliation, true)
    }

    func testRetryAfterCancellationFailureCanRestorePreviousAlarm() async throws {
        let client = TestPhoneAlarmClient(authorization: .authorized)
        let store = TestPhoneAlarmInstallationStore()
        let coordinator = PhoneAlarmCoordinator(client: client, installationStore: store)
        let first = makeCoordinatorPayload()
        let secondID = coordinatorTestUUID("00000000-0000-0000-0000-000000000035")
        let second = makeCoordinatorPayload(scheduleID: secondID, revisionSequence: 2)
        _ = try await coordinator.apply(first, requestingAuthorization: false)
        await client.failNextCancellation()
        do {
            _ = try await coordinator.apply(second, requestingAuthorization: false)
            XCTFail("Expected the first cancellation to fail")
        } catch PhoneAlarmCoordinatorError.cancellationFailed {}
        await client.failNextSchedule()

        do {
            _ = try await coordinator.apply(second, requestingAuthorization: false)
            XCTFail("Expected the retry schedule to fail")
        } catch TestPhoneAlarmClientError.scheduleFailed {}

        let activeAlarmIDs = try await client.scheduledAlarmIDs()
        let reconciliation = try await coordinator.reconcile(first)
        XCTAssertEqual(activeAlarmIDs, [first.alarmID])
        XCTAssertEqual(reconciliation, .scheduled)
    }

    func testRollbackContinuesWhenNewAlarmCancellationFails() async throws {
        let client = TestPhoneAlarmClient(authorization: .authorized)
        let store = TestPhoneAlarmInstallationStore()
        let coordinator = PhoneAlarmCoordinator(client: client, installationStore: store)
        let first = makeCoordinatorPayload()
        let secondID = coordinatorTestUUID("00000000-0000-0000-0000-000000000033")
        let second = makeCoordinatorPayload(scheduleID: secondID, revisionSequence: 2)
        _ = try await coordinator.apply(first, requestingAuthorization: false)
        await client.failAfterNextSchedule()
        await client.failCancellation(afterSuccessfulCancellations: 1)

        do {
            _ = try await coordinator.apply(second, requestingAuthorization: false)
            XCTFail("Expected replacement cleanup to remain pending")
        } catch PhoneAlarmCoordinatorError.replacementRestoredWithCleanupPending {
            // The prior alarm is restored and both IDs remain recorded for the next retry.
        }

        let activeAlarmIDs = try await client.scheduledAlarmIDs()
        let installation = try await store.load()
        XCTAssertTrue(activeAlarmIDs.contains(first.alarmID))
        XCTAssertTrue(activeAlarmIDs.contains(second.alarmID))
        XCTAssertEqual(installation?.payload, first)
        XCTAssertEqual(installation?.managedAlarmIDs, [first.alarmID, second.alarmID])
        XCTAssertEqual(installation?.requiresReconciliation, true)
    }

    func testCleanupCancelsKnownAlarmWithoutInstallationRecord() async throws {
        let client = TestPhoneAlarmClient(authorization: .authorized)
        let coordinator = makeTestCoordinator(client: client)
        let orphan = makeCoordinatorPayload()
        try await client.schedule(orphan)

        try await coordinator.removeInstalledAlarm(candidatePayload: orphan)

        let activeAlarmIDs = try await client.scheduledAlarmIDs()
        XCTAssertTrue(activeAlarmIDs.isEmpty)
    }

    func testCleanupFailurePersistsOrphanForFreshCoordinatorRetry() async throws {
        let client = TestPhoneAlarmClient(authorization: .authorized)
        let store = TestPhoneAlarmInstallationStore()
        let coordinator = PhoneAlarmCoordinator(client: client, installationStore: store)
        let orphan = makeCoordinatorPayload()
        try await client.schedule(orphan)
        await client.failNextCancellation()

        do {
            try await coordinator.removeInstalledAlarm(candidatePayload: orphan)
            XCTFail("Expected orphan cleanup to fail")
        } catch PhoneAlarmCoordinatorError.cancellationFailed {}

        let freshCoordinator = PhoneAlarmCoordinator(
            client: client,
            installationStore: store
        )
        try await freshCoordinator.removeInstalledAlarm()

        let activeAlarmIDs = try await client.scheduledAlarmIDs()
        let installation = try await store.load()
        XCTAssertTrue(activeAlarmIDs.isEmpty)
        XCTAssertEqual(installation, nil)
    }

    func testCleanupQueryFailurePersistsOrphanForFreshCoordinatorRetry() async throws {
        let client = TestPhoneAlarmClient(authorization: .authorized)
        let store = TestPhoneAlarmInstallationStore()
        let coordinator = PhoneAlarmCoordinator(client: client, installationStore: store)
        let orphan = makeCoordinatorPayload()
        try await client.schedule(orphan)
        await client.failNextActiveAlarmQuery()

        do {
            try await coordinator.removeInstalledAlarm(candidatePayload: orphan)
            XCTFail("Expected the active-alarm query to fail")
        } catch TestPhoneAlarmClientError.activeAlarmQueryFailed {}

        let journal = try await store.load()
        XCTAssertEqual(journal?.managedAlarmIDs, [orphan.alarmID])
        XCTAssertEqual(journal?.requiresReconciliation, true)

        let freshCoordinator = PhoneAlarmCoordinator(
            client: client,
            installationStore: store
        )
        try await freshCoordinator.removeInstalledAlarm()

        let activeAlarmIDs = try await client.scheduledAlarmIDs()
        let installation = try await store.load()
        XCTAssertTrue(activeAlarmIDs.isEmpty)
        XCTAssertEqual(installation, nil)
    }

    func testInterruptedTransactionRequiresReconciliation() async throws {
        let client = TestPhoneAlarmClient(authorization: .authorized)
        let store = TestPhoneAlarmInstallationStore()
        let coordinator = PhoneAlarmCoordinator(client: client, installationStore: store)
        let previous = makeCoordinatorPayload()
        let incomingID = coordinatorTestUUID("00000000-0000-0000-0000-000000000034")
        let incoming = makeCoordinatorPayload(scheduleID: incomingID, revisionSequence: 2)
        try await store.save(
            PhoneAlarmInstallation(
                payload: incoming,
                installedAt: .now,
                managedAlarmIDs: [previous.alarmID, incoming.alarmID],
                requiresReconciliation: true,
                recoveryPayload: previous
            )
        )

        let result = try await coordinator.reconcile(incoming)

        XCTAssertEqual(result, .updateRequired(previouslyInstalled: true))
    }
}

private func makeTestCoordinator(client: TestPhoneAlarmClient) -> PhoneAlarmCoordinator {
    let fileURL = URL.temporaryDirectory
        .appending(path: "wakebar-installation-\(UUID().uuidString).json")
    return PhoneAlarmCoordinator(
        client: client,
        installationStore: PhoneAlarmInstallationStore(fileURL: fileURL)
    )
}

private func makeCoordinatorPayload(
    scheduleID: UUID = coordinatorTestUUID("00000000-0000-0000-0000-000000000030"),
    revisionSequence: Int64 = 1,
    isEnabled: Bool = true
) -> PhoneAlarmSchedulePayload {
    PhoneAlarmSchedulePayload(
        scheduleID: scheduleID,
        alarmID: scheduleID,
        revision: PhoneScheduleRevision(
            sequence: revisionSequence,
            modifiedAt: Date(timeIntervalSince1970: 1_800_000_000),
            writerID: "test-mac"
        ),
        isEnabled: isEnabled,
        title: "Wake up",
        hour: 7,
        minute: 0,
        weekdays: Weekday.workweek,
        followsDeviceTimeZone: true,
        sourceTimeZoneIdentifier: "UTC"
    )
}

private func coordinatorTestUUID(_ value: String) -> UUID {
    guard let identifier = UUID(uuidString: value) else {
        fatalError("Invalid coordinator test UUID: \(value)")
    }
    return identifier
}
