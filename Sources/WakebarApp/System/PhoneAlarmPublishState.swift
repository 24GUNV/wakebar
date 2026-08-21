import Foundation
import WakebarCore

enum PhoneAlarmPublishState: Equatable {
    case draft
    case publishing
    case published(PhoneAlarmPublishReceipt)
    case confirmed(PhoneAlarmAcknowledgement)
    case failed(String)
}
