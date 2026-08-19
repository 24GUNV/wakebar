import Foundation

public struct CachedPhoneAlarmSchedule: Codable, Equatable, Sendable {
    public let payload: PhoneAlarmSchedulePayload
    public let lastSuccessfulSync: Date
    public let accountRecordName: String

    public init(
        payload: PhoneAlarmSchedulePayload,
        lastSuccessfulSync: Date,
        accountRecordName: String
    ) {
        self.payload = payload
        self.lastSuccessfulSync = lastSuccessfulSync
        self.accountRecordName = accountRecordName
    }
}
