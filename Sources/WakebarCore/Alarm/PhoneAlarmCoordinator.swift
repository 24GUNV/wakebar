import Foundation

public actor PhoneAlarmCoordinator {
    private let client: any PhoneAlarmClient
    private let installationStore: any PhoneAlarmInstallationPersisting

    public init(
        client: any PhoneAlarmClient,
        installationStore: any PhoneAlarmInstallationPersisting = PhoneAlarmInstallationStore()
    ) {
        self.client = client
        self.installationStore = installationStore
    }

    public func authorizationState() async -> PhoneAlarmAuthorizationState {
        await client.authorizationState()
    }

    public func apply(
        _ payload: PhoneAlarmSchedulePayload,
        requestingAuthorization: Bool
    ) async throws -> PhoneAlarmApplicationResult {
        let payload = try payload.validated()
        let persistedInstallation = try await installationStore.load()
        let installation = previousInstallation(from: persistedInstallation)
        let scheduledAlarmIDs = try await client.scheduledAlarmIDs()

        guard payload.isEnabled else {
            let managedAlarmIDs = managedAlarmIDs(
                installation: persistedInstallation,
                candidates: [payload.alarmID]
            )
            try await saveTransactionJournal(
                incomingPayload: payload,
                previousInstallation: installation,
                managedAlarmIDs: managedAlarmIDs
            )
            let failedCancellations = await cancel(
                managedAlarmIDs.intersection(scheduledAlarmIDs)
            )
            guard failedCancellations.isEmpty else {
                throw PhoneAlarmCoordinatorError.cancellationFailed
            }
            try await installationStore.clear()
            return .inactive
        }

        var authorization = await client.authorizationState()
        if authorization == .notDetermined, requestingAuthorization {
            authorization = try await client.requestAuthorization()
        }

        switch authorization {
        case .notDetermined:
            return .permissionRequired
        case .denied:
            return .permissionDenied
        case let .unavailable(reason):
            return .unavailable(reason)
        case .authorized:
            let managedAlarmIDs = managedAlarmIDs(
                installation: persistedInstallation,
                candidates: [payload.alarmID]
            )
            try await saveTransactionJournal(
                incomingPayload: payload,
                previousInstallation: installation,
                managedAlarmIDs: managedAlarmIDs
            )
            let failedCancellations = await cancel(
                managedAlarmIDs.intersection(scheduledAlarmIDs)
            )
            guard failedCancellations.isEmpty else {
                do {
                    try await preserveRecoveryState(
                        previousInstallation: installation,
                        incomingPayload: payload,
                        managedAlarmIDs: managedAlarmIDs
                    )
                } catch {
                    throw PhoneAlarmCoordinatorError.replacementAndRestoreFailed
                }
                throw PhoneAlarmCoordinatorError.cancellationFailed
            }

            do {
                try await client.schedule(payload)
                try await installationStore.save(
                    PhoneAlarmInstallation(
                        payload: payload,
                        installedAt: .now
                    )
                )
            } catch let replacementError {
                try await recoverAfterReplacementFailure(
                    replacementError,
                    previousInstallation: installation,
                    incomingPayload: payload,
                    managedAlarmIDs: managedAlarmIDs
                )
            }
            return .scheduled(alarmID: payload.alarmID, revision: payload.revision)
        }
    }

    public func reconcile(
        _ payload: PhoneAlarmSchedulePayload
    ) async throws -> PhoneAlarmReconciliationResult {
        let payload = try payload.validated()
        if !payload.isEnabled {
            let installation = try await installationStore.load()
            let alarmIDs = try await client.scheduledAlarmIDs()
            if installation != nil || alarmIDs.contains(payload.alarmID) {
                return .updateRequired(previouslyInstalled: true)
            }
            return .inactive
        }

        switch await client.authorizationState() {
        case .notDetermined:
            return .permissionRequired
        case .denied:
            return .permissionDenied
        case let .unavailable(reason):
            return .unavailable(reason)
        case .authorized:
            break
        }

        let installation = try await installationStore.load()
        guard let installation else {
            return .updateRequired(previouslyInstalled: false)
        }
        guard !installation.requiresReconciliation else {
            return .updateRequired(previouslyInstalled: true)
        }
        guard installation.alarmID == payload.alarmID,
              installation.revision == payload.revision
        else {
            return .updateRequired(previouslyInstalled: true)
        }

        let alarmIDs = try await client.scheduledAlarmIDs()
        let unexpectedManagedAlarmIDs = installation.managedAlarmIDs
            .subtracting([payload.alarmID])
            .intersection(alarmIDs)
        guard unexpectedManagedAlarmIDs.isEmpty else {
            return .updateRequired(previouslyInstalled: true)
        }
        return alarmIDs.contains(payload.alarmID) ? .scheduled : .alarmMissing
    }

    public func alarmUpdates() async -> AsyncStream<Set<UUID>> {
        await client.alarmUpdates()
    }

    public func removeInstalledAlarm(
        candidatePayload: PhoneAlarmSchedulePayload? = nil
    ) async throws {
        let installation = try await installationStore.load()
        let candidateAlarmIDs = Set(candidatePayload.map { [$0.alarmID] } ?? [])
        let managedAlarmIDs = managedAlarmIDs(
            installation: installation,
            candidates: candidateAlarmIDs
        )
        if installation == nil, let candidatePayload {
            try await installationStore.save(
                PhoneAlarmInstallation(
                    payload: candidatePayload,
                    installedAt: .now,
                    managedAlarmIDs: managedAlarmIDs,
                    requiresReconciliation: true
                )
            )
        }
        let scheduledAlarmIDs = try await client.scheduledAlarmIDs()
        let failedCancellations = await cancel(
            managedAlarmIDs.intersection(scheduledAlarmIDs)
        )
        guard failedCancellations.isEmpty else {
            if let installation {
                try await installationStore.save(
                    PhoneAlarmInstallation(
                        payload: installation.payload,
                        installedAt: installation.installedAt,
                        managedAlarmIDs: managedAlarmIDs,
                        requiresReconciliation: true,
                        recoveryPayload: installation.recoveryPayload
                    )
                )
            }
            throw PhoneAlarmCoordinatorError.cancellationFailed
        }
        try await installationStore.clear()
    }

    private func managedAlarmIDs(
        installation: PhoneAlarmInstallation?,
        candidates: Set<UUID>
    ) -> Set<UUID> {
        var alarmIDs = candidates
        if let installation {
            alarmIDs.formUnion(installation.managedAlarmIDs)
            alarmIDs.insert(installation.alarmID)
        }
        return alarmIDs
    }

    private func previousInstallation(
        from installation: PhoneAlarmInstallation?
    ) -> PhoneAlarmInstallation? {
        guard let installation else { return nil }
        guard installation.requiresReconciliation else { return installation }
        guard let recoveryPayload = installation.recoveryPayload else { return nil }
        return PhoneAlarmInstallation(
            payload: recoveryPayload,
            installedAt: installation.installedAt,
            managedAlarmIDs: installation.managedAlarmIDs
        )
    }

    private func saveTransactionJournal(
        incomingPayload: PhoneAlarmSchedulePayload,
        previousInstallation: PhoneAlarmInstallation?,
        managedAlarmIDs: Set<UUID>
    ) async throws {
        try await installationStore.save(
            PhoneAlarmInstallation(
                payload: incomingPayload,
                installedAt: .now,
                managedAlarmIDs: managedAlarmIDs,
                requiresReconciliation: true,
                recoveryPayload: previousInstallation?.payload
            )
        )
    }

    private func cancel(_ alarmIDs: Set<UUID>) async -> Set<UUID> {
        var failures: Set<UUID> = []
        for alarmID in alarmIDs {
            do {
                try await client.cancel(alarmID: alarmID)
            } catch {
                failures.insert(alarmID)
            }
        }
        return failures
    }

    private func preserveRecoveryState(
        previousInstallation: PhoneAlarmInstallation?,
        incomingPayload: PhoneAlarmSchedulePayload,
        managedAlarmIDs: Set<UUID>
    ) async throws {
        if let previousInstallation {
            let activeAlarmIDs = try await client.scheduledAlarmIDs()
            if !activeAlarmIDs.contains(previousInstallation.alarmID) {
                try await client.schedule(previousInstallation.payload)
            }
            try await installationStore.save(
                PhoneAlarmInstallation(
                    payload: previousInstallation.payload,
                    installedAt: previousInstallation.installedAt,
                    managedAlarmIDs: managedAlarmIDs,
                    requiresReconciliation: true,
                    recoveryPayload: previousInstallation.payload
                )
            )
        } else {
            try await installationStore.save(
                PhoneAlarmInstallation(
                    payload: incomingPayload,
                    installedAt: .now,
                    managedAlarmIDs: managedAlarmIDs,
                    requiresReconciliation: true
                )
            )
        }
    }

    private func recoverAfterReplacementFailure(
        _ replacementError: any Error,
        previousInstallation: PhoneAlarmInstallation?,
        incomingPayload: PhoneAlarmSchedulePayload,
        managedAlarmIDs: Set<UUID>
    ) async throws -> Never {
        let activeAlarmIDs = (try? await client.scheduledAlarmIDs()) ?? managedAlarmIDs
        let failedCancellations = await cancel(
            managedAlarmIDs.intersection(activeAlarmIDs)
        )

        guard let previousInstallation else {
            if failedCancellations.isEmpty {
                do {
                    try await installationStore.clear()
                } catch {
                    throw PhoneAlarmCoordinatorError.replacementAndRestoreFailed
                }
                throw replacementError
            }
            do {
                try await preserveRecoveryState(
                    previousInstallation: nil,
                    incomingPayload: incomingPayload,
                    managedAlarmIDs: managedAlarmIDs
                )
            } catch {
                throw PhoneAlarmCoordinatorError.replacementAndRestoreFailed
            }
            throw PhoneAlarmCoordinatorError.replacementRestoredWithCleanupPending
        }

        do {
            try await client.schedule(previousInstallation.payload)
            try await installationStore.save(
                PhoneAlarmInstallation(
                    payload: previousInstallation.payload,
                    installedAt: previousInstallation.installedAt,
                    managedAlarmIDs: managedAlarmIDs,
                    requiresReconciliation: !failedCancellations.isEmpty,
                    recoveryPayload: failedCancellations.isEmpty
                        ? nil
                        : previousInstallation.payload
                )
            )
        } catch {
            throw PhoneAlarmCoordinatorError.replacementAndRestoreFailed
        }

        if failedCancellations.isEmpty {
            throw replacementError
        }
        throw PhoneAlarmCoordinatorError.replacementRestoredWithCleanupPending
    }
}
