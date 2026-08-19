import Foundation
import WakebarCore

enum PhoneAlarmPublishState: Equatable {
    case draft
    case publishing
    case published(PhoneAlarmPublishReceipt)
    case confirmed(PhoneAlarmAcknowledgement)
    case failed(String)

    var displayName: String {
        switch self {
        case .draft:
            "Not synced"
        case .publishing:
            "Syncing"
        case .published:
            "Awaiting iPhone"
        case .confirmed:
            "Alarm confirmed"
        case .failed:
            "Sync failed"
        }
    }
}
