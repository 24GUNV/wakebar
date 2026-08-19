import Foundation

public struct UnavailablePhoneAlarmClient: PhoneAlarmClient {
    public let reason: String

    public init(reason: String) {
        self.reason = reason
    }

    public func authorizationState() async -> PhoneAlarmAuthorizationState {
        .unavailable(reason)
    }

    public func requestAuthorization() async throws -> PhoneAlarmAuthorizationState {
        .unavailable(reason)
    }

    public func schedule(_ payload: PhoneAlarmSchedulePayload) async throws {
        _ = payload
        throw PhoneAlarmClientError.unavailable(reason)
    }

    public func cancel(alarmID: UUID) async throws {
        _ = alarmID
    }

    public func scheduledAlarmIDs() async throws -> Set<UUID> { [] }

    public func alarmUpdates() async -> AsyncStream<Set<UUID>> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
