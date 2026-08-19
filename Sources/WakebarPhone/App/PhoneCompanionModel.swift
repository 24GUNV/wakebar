import Foundation
import Observation
import WakebarCore

@MainActor
@Observable
final class PhoneCompanionModel {
    private let coordinator: PhoneAlarmCoordinator
    private let repository: any PhoneAlarmScheduleRepository
    private let operationQueue = PhoneCompanionOperationQueue()
    private var operationGeneration = 0
    @ObservationIgnored private var alarmObservationTask: Task<Void, Never>?

    private(set) var authorization: PhoneAlarmAuthorizationState = .notDetermined
    private(set) var latestPayload: PhoneAlarmSchedulePayload?
    private(set) var deliveryState: PhoneScheduleDeliveryState = .neverChecked
    private(set) var subscriptionState: PhoneScheduleSubscriptionState = .notInstalled
    private(set) var acknowledgementError: String?
    private(set) var status: PhoneCompanionStatus = .waitingForSchedule
    private(set) var isBusy = false

    init(
        client: any PhoneAlarmClient,
        repository: any PhoneAlarmScheduleRepository,
        payload: PhoneAlarmSchedulePayload? = nil
    ) {
        coordinator = PhoneAlarmCoordinator(client: client)
        self.repository = repository
        latestPayload = payload
        status = payload == nil ? .waitingForSchedule : .permissionRequired
    }

    func refresh() async {
        await operationQueue.run { [self] in
            await refreshImpl()
        }
    }

    private func refreshImpl() async {
        startAlarmObservationIfNeeded()
        let generation = beginOperation()
        async let subscription = repository.installChangeSubscription()
        let delivery = await repository.fetchLatest()
        guard generation == operationGeneration else { return }

        let resolvedSubscription = await subscription
        guard generation == operationGeneration else { return }
        subscriptionState = resolvedSubscription
        deliveryState = delivery
        if let payload = delivery.payload {
            if let current = latestPayload {
                if payload.shouldReplace(current) {
                    latestPayload = payload
                }
            } else {
                latestPayload = payload
            }
        } else if delivery.requiresLocalScheduleRemoval {
            do {
                try await coordinator.removeInstalledAlarm(candidatePayload: latestPayload)
                latestPayload = nil
            } catch {
                status = .failed(error.localizedDescription)
                return
            }
        }

        authorization = await coordinator.authorizationState()
        guard latestPayload != nil else {
            status = Self.status(for: delivery)
            return
        }

        await reconcileLatestPayload()
    }

    func refreshFromBackground() async -> PhoneBackgroundRefreshResult {
        let previousRevision = latestPayload?.revision
        await refresh()
        switch deliveryState {
        case .unavailable, .stale:
            return .failed
        case .neverChecked:
            return .failed
        case .noSchedule, .accountChanged, .current:
            return previousRevision != latestPayload?.revision ? .newData : .noData
        }
    }

    private func reconcileLatestPayload() async {
        guard let latestPayload else {
            status = .waitingForSchedule
            return
        }
        let revision = latestPayload.revision
        let generation = operationGeneration

        do {
            let result = try await coordinator.reconcile(latestPayload)
            guard generation == operationGeneration,
                  self.latestPayload?.revision == revision
            else { return }
            switch result {
            case .inactive:
                status = .inactive
                await acknowledgeInstallation(of: latestPayload)
            case .permissionRequired:
                status = .permissionRequired
            case .permissionDenied:
                status = .permissionDenied
            case let .unavailable(reason):
                status = .unavailable(reason)
            case let .updateRequired(previouslyInstalled):
                if previouslyInstalled {
                    await applyLatestPayload(requestingAuthorization: false)
                } else {
                    status = .readyToSet
                }
            case .alarmMissing:
                status = .alarmMissing
            case .scheduled:
                status = .armed
                await acknowledgeInstallation(of: latestPayload)
            }
        } catch {
            guard generation == operationGeneration,
                  self.latestPayload?.revision == revision
            else { return }
            status = .failed(error.localizedDescription)
        }
    }

    private func startAlarmObservationIfNeeded() {
        guard alarmObservationTask == nil else { return }
        alarmObservationTask = Task { [weak self] in
            guard let self else { return }
            let updates = await coordinator.alarmUpdates()
            for await alarmIDs in updates {
                guard !Task.isCancelled else { return }
                await handleAlarmUpdate(alarmIDs)
            }
        }
    }

    private func handleAlarmUpdate(_ alarmIDs: Set<UUID>) async {
        await operationQueue.run { [self] in
            await handleAlarmUpdateImpl(alarmIDs)
        }
    }

    private func handleAlarmUpdateImpl(_ alarmIDs: Set<UUID>) async {
        guard let latestPayload, latestPayload.isEnabled else { return }
        if alarmIDs.contains(latestPayload.alarmID) {
            await reconcileLatestPayload()
        } else if status == .armed {
            status = .alarmMissing
        }
    }

    func allowAndSetAlarm() async {
        await operationQueue.run { [self] in
            await allowAndSetAlarmImpl()
        }
    }

    private func allowAndSetAlarmImpl() async {
        _ = beginOperation()
        await applyLatestPayload(requestingAuthorization: true)
    }

    private func beginOperation() -> Int {
        operationGeneration += 1
        isBusy = false
        return operationGeneration
    }

    private func applyLatestPayload(requestingAuthorization: Bool) async {
        guard let latestPayload else {
            status = .waitingForSchedule
            return
        }
        let revision = latestPayload.revision
        let generation = operationGeneration

        isBusy = true
        status = .scheduling
        defer {
            if generation == operationGeneration {
                isBusy = false
            }
        }

        do {
            let result = try await coordinator.apply(
                latestPayload,
                requestingAuthorization: requestingAuthorization
            )
            guard generation == operationGeneration,
                  self.latestPayload?.revision == revision
            else { return }
            authorization = await coordinator.authorizationState()
            status = Self.status(for: result)
            switch result {
            case .scheduled, .inactive:
                await acknowledgeInstallation(of: latestPayload)
            case .permissionRequired, .permissionDenied, .unavailable:
                break
            }
        } catch {
            guard generation == operationGeneration,
                  self.latestPayload?.revision == revision
            else { return }
            status = .failed(error.localizedDescription)
        }
    }

    private func acknowledgeInstallation(of payload: PhoneAlarmSchedulePayload) async {
        do {
            try await repository.acknowledge(
                PhoneAlarmAcknowledgement(
                    scheduleID: payload.scheduleID,
                    alarmID: payload.alarmID,
                    revision: payload.revision,
                    confirmedAt: .now
                )
            )
            acknowledgementError = nil
        } catch {
            acknowledgementError = error.localizedDescription
        }
    }

    private static func status(for result: PhoneAlarmApplicationResult) -> PhoneCompanionStatus {
        switch result {
        case .inactive: .inactive
        case .permissionRequired: .permissionRequired
        case .permissionDenied: .permissionDenied
        case let .unavailable(reason): .unavailable(reason)
        case .scheduled: .armed
        }
    }

    private static func status(for delivery: PhoneScheduleDeliveryState) -> PhoneCompanionStatus {
        switch delivery {
        case .neverChecked, .noSchedule:
            .waitingForSchedule
        case let .accountChanged(reason, _), let .unavailable(reason, _):
            .unavailable(reason)
        case .current, .stale:
            .permissionRequired
        }
    }
}

private extension PhoneScheduleDeliveryState {
    var requiresLocalScheduleRemoval: Bool {
        switch self {
        case .noSchedule, .accountChanged: true
        case .neverChecked, .current, .stale, .unavailable: false
        }
    }
}
