import Foundation

public struct TriggerRequest: Sendable {
    public let scheduleID: UUID
    public let plannedFireDate: Date
    public let prompt: String

    public init(scheduleID: UUID, plannedFireDate: Date, prompt: String) {
        self.scheduleID = scheduleID
        self.plannedFireDate = plannedFireDate
        self.prompt = prompt
    }

    public var occurrenceID: String {
        "\(scheduleID.uuidString):\(plannedFireDate.timeIntervalSince1970.rounded())"
    }
}
