import Foundation

public struct ProviderDeliveryState: Codable, Equatable, Sendable {
    public let provider: ProviderID
    public let desiredRevision: UUID
    public let appliedRevision: UUID?
    public let phase: ProviderDeliveryPhase
    public let lastConfirmedAt: Date?
    public let detail: String?

    public init(
        provider: ProviderID,
        desiredRevision: UUID,
        appliedRevision: UUID? = nil,
        phase: ProviderDeliveryPhase,
        lastConfirmedAt: Date? = nil,
        detail: String? = nil
    ) {
        self.provider = provider
        self.desiredRevision = desiredRevision
        self.appliedRevision = appliedRevision
        self.phase = phase
        self.lastConfirmedAt = lastConfirmedAt
        self.detail = detail
    }

    public var isCurrentRevisionConfirmed: Bool {
        phase == .confirmed && appliedRevision == desiredRevision
    }

    public static func draft(provider: ProviderID, revision: UUID) -> Self {
        Self(provider: provider, desiredRevision: revision, phase: .draft)
    }
}
