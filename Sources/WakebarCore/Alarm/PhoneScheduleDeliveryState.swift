import Foundation

public enum PhoneScheduleDeliveryState: Equatable, Sendable {
    case neverChecked
    case noSchedule(checkedAt: Date)
    case current(PhoneAlarmSchedulePayload, checkedAt: Date)
    case stale(PhoneAlarmSchedulePayload, lastSuccessfulSync: Date, reason: String)
    case accountChanged(reason: String, checkedAt: Date)
    case unavailable(reason: String, checkedAt: Date)

    public var payload: PhoneAlarmSchedulePayload? {
        switch self {
        case let .current(payload, _), let .stale(payload, _, _): payload
        case .neverChecked, .noSchedule, .accountChanged, .unavailable: nil
        }
    }
}
