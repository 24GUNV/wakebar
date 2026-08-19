import Foundation

public protocol PhoneAlarmClient: Sendable {
    func authorizationState() async -> PhoneAlarmAuthorizationState
    func requestAuthorization() async throws -> PhoneAlarmAuthorizationState
    func schedule(_ payload: PhoneAlarmSchedulePayload) async throws
    func cancel(alarmID: UUID) async throws
    func scheduledAlarmIDs() async throws -> Set<UUID>
    func alarmUpdates() async -> AsyncStream<Set<UUID>>
}
