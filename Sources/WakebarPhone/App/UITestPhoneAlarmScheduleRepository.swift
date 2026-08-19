import Foundation
import WakebarCore

struct UITestPhoneAlarmScheduleRepository: PhoneAlarmScheduleRepository {
    func fetchLatest() async -> PhoneScheduleDeliveryState {
        .noSchedule(checkedAt: .now)
    }

    func installChangeSubscription() async -> PhoneScheduleSubscriptionState {
        .notInstalled
    }

    func publish(_ payload: PhoneAlarmSchedulePayload) async throws {
        _ = payload
        throw PhoneAlarmClientError.unavailable("Safe UI test mode")
    }

    func acknowledge(_ acknowledgement: PhoneAlarmAcknowledgement) async throws {
        _ = acknowledgement
        throw PhoneAlarmClientError.unavailable("Safe UI test mode")
    }

    func acknowledgement(for scheduleID: UUID) async throws -> PhoneAlarmAcknowledgement? {
        _ = scheduleID
        return nil
    }
}
