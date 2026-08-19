import Foundation

public protocol PhoneAlarmScheduleRepository: Sendable {
    func fetchLatest() async -> PhoneScheduleDeliveryState
    func installChangeSubscription() async -> PhoneScheduleSubscriptionState
    func publish(_ payload: PhoneAlarmSchedulePayload) async throws
    func acknowledge(_ acknowledgement: PhoneAlarmAcknowledgement) async throws
    func acknowledgement(for scheduleID: UUID) async throws -> PhoneAlarmAcknowledgement?
}
