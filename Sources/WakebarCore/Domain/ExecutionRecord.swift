import Foundation

public struct ExecutionRecord: Codable, Equatable, Sendable {
    public let eventID: String
    public var state: ExecutionDeliveryState
    public var updatedAt: Date

    public init(eventID: String, state: ExecutionDeliveryState, updatedAt: Date) {
        self.eventID = eventID
        self.state = state
        self.updatedAt = updatedAt
    }
}
