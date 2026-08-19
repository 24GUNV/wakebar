import Foundation

public struct ScheduledEvent: Identifiable, Equatable, Sendable {
    public let id: String
    public let scheduleID: UUID
    public let date: Date
    public let wakeDate: Date
    public let kind: ScheduledEventKind

    public init(scheduleID: UUID, date: Date, wakeDate: Date, kind: ScheduledEventKind) {
        id = "\(scheduleID.uuidString):\(kind.stableKey):\(date.timeIntervalSince1970.rounded())"
        self.scheduleID = scheduleID
        self.date = date
        self.wakeDate = wakeDate
        self.kind = kind
    }
}
