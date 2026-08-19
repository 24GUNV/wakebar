#if os(iOS) && canImport(AlarmKit)
import AlarmKit

@available(iOS 26.0, *)
public struct WakebarAlarmMetadata: AlarmMetadata {
    public let scheduleID: String
    public let revisionSequence: Int64

    public init(scheduleID: String, revisionSequence: Int64) {
        self.scheduleID = scheduleID
        self.revisionSequence = revisionSequence
    }
}
#endif
