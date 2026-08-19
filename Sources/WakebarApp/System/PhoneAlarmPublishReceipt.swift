import Foundation
import WakebarCore

struct PhoneAlarmPublishReceipt: Equatable, Sendable {
    let scheduleID: UUID
    let revision: PhoneScheduleRevision
    let publishedAt: Date
}
