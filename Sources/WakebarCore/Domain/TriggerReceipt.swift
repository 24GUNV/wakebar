import Foundation

public struct TriggerReceipt: Identifiable, Codable, Sendable {
    public let id: UUID
    public let provider: ProviderID
    public let occurredAt: Date
    public let outcome: TriggerOutcome

    public init(id: UUID, provider: ProviderID, occurredAt: Date, outcome: TriggerOutcome) {
        self.id = id
        self.provider = provider
        self.occurredAt = occurredAt
        self.outcome = outcome
    }
}
