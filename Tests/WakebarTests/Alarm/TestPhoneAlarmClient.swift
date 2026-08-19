import Foundation
@testable import WakebarCore

actor TestPhoneAlarmClient: PhoneAlarmClient {
    private var authorization: PhoneAlarmAuthorizationState
    private var scheduledPayloads: [PhoneAlarmSchedulePayload] = []
    private var cancelledAlarmIDs: [UUID] = []
    private var activeAlarmIDs: Set<UUID> = []
    private var authorizationRequestCount = 0
    private var scheduleFailuresRemaining = 0
    private var postScheduleFailuresRemaining = 0
    private var cancellationFailuresRemaining = 0
    private var cancellationCallsBeforeFailure: Int?
    private var activeAlarmQueryFailuresRemaining = 0

    init(authorization: PhoneAlarmAuthorizationState) {
        self.authorization = authorization
    }

    func authorizationState() async -> PhoneAlarmAuthorizationState {
        authorization
    }

    func requestAuthorization() async throws -> PhoneAlarmAuthorizationState {
        authorizationRequestCount += 1
        authorization = .authorized
        return authorization
    }

    func schedule(_ payload: PhoneAlarmSchedulePayload) async throws {
        if scheduleFailuresRemaining > 0 {
            scheduleFailuresRemaining -= 1
            throw TestPhoneAlarmClientError.scheduleFailed
        }
        scheduledPayloads.append(payload)
        activeAlarmIDs.insert(payload.alarmID)
        if postScheduleFailuresRemaining > 0 {
            postScheduleFailuresRemaining -= 1
            throw TestPhoneAlarmClientError.scheduleFailed
        }
    }

    func cancel(alarmID: UUID) async throws {
        if let callsBeforeFailure = cancellationCallsBeforeFailure {
            if callsBeforeFailure == 0 {
                cancellationCallsBeforeFailure = nil
                throw TestPhoneAlarmClientError.cancelFailed
            }
            cancellationCallsBeforeFailure = callsBeforeFailure - 1
        }
        if cancellationFailuresRemaining > 0 {
            cancellationFailuresRemaining -= 1
            throw TestPhoneAlarmClientError.cancelFailed
        }
        cancelledAlarmIDs.append(alarmID)
        activeAlarmIDs.remove(alarmID)
    }

    func scheduledAlarmIDs() async throws -> Set<UUID> {
        if activeAlarmQueryFailuresRemaining > 0 {
            activeAlarmQueryFailuresRemaining -= 1
            throw TestPhoneAlarmClientError.activeAlarmQueryFailed
        }
        return activeAlarmIDs
    }

    func alarmUpdates() async -> AsyncStream<Set<UUID>> {
        let alarmIDs = activeAlarmIDs
        return AsyncStream { continuation in
            continuation.yield(alarmIDs)
            continuation.finish()
        }
    }

    func snapshot() -> (scheduled: [PhoneAlarmSchedulePayload], cancelled: [UUID], requestCount: Int) {
        (scheduledPayloads, cancelledAlarmIDs, authorizationRequestCount)
    }

    func failNextSchedule() {
        scheduleFailuresRemaining += 1
    }

    func failAfterNextSchedule() {
        postScheduleFailuresRemaining += 1
    }

    func failNextCancellation() {
        cancellationFailuresRemaining += 1
    }

    func failCancellation(afterSuccessfulCancellations count: Int) {
        cancellationCallsBeforeFailure = count
    }

    func failNextActiveAlarmQuery() {
        activeAlarmQueryFailuresRemaining += 1
    }
}
