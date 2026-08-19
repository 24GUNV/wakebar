import Foundation

public struct UnavailablePhoneAlarmScheduleRepository: PhoneAlarmScheduleRepository {
    public let reason: String

    public init(reason: String) {
        self.reason = reason
    }

    public func fetchLatest() async -> PhoneScheduleDeliveryState {
        .unavailable(reason: reason, checkedAt: .now)
    }

    public func installChangeSubscription() async -> PhoneScheduleSubscriptionState {
        .unavailable(reason)
    }

    public func publish(_ payload: PhoneAlarmSchedulePayload) async throws {
        _ = payload
        throw PhoneAlarmClientError.unavailable(reason)
    }

    public func acknowledge(_ acknowledgement: PhoneAlarmAcknowledgement) async throws {
        _ = acknowledgement
        throw PhoneAlarmClientError.unavailable(reason)
    }

    public func acknowledgement(for scheduleID: UUID) async throws -> PhoneAlarmAcknowledgement? {
        _ = scheduleID
        throw PhoneAlarmClientError.unavailable(reason)
    }
}
