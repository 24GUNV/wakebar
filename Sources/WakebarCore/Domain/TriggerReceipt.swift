import Foundation

public struct TriggerReceipt: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let provider: ProviderID
    public let occurredAt: Date
    public let outcome: TriggerOutcome
    public let externalID: String?
    public let externalURL: URL?

    public init(
        id: UUID,
        provider: ProviderID,
        occurredAt: Date,
        outcome: TriggerOutcome,
        externalID: String? = nil,
        externalURL: URL? = nil
    ) {
        self.id = id
        self.provider = provider
        self.occurredAt = occurredAt
        self.outcome = outcome
        self.externalID = externalID
        self.externalURL = externalURL
    }
}
