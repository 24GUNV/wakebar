import Foundation

public struct DryRunProviderAdapter: ProviderAdapter {
    public let id: ProviderID

    public init(id: ProviderID) {
        self.id = id
    }

    public func probe() async -> ProviderSnapshot {
        .notConnected(id)
    }

    public func preview(_ request: TriggerRequest) async throws -> TriggerReceipt {
        _ = request.occurrenceID

        return TriggerReceipt(
            id: UUID(),
            provider: id,
            occurredAt: .now,
            outcome: .previewed
        )
    }

    public func trigger(_ request: TriggerRequest) async throws -> TriggerReceipt {
        _ = request
        throw ProviderAdapterError.liveExecutionNotConfigured
    }
}
