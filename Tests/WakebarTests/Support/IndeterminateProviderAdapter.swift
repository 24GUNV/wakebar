import Foundation
@testable import WakebarCore

struct IndeterminateProviderAdapter: ProviderAdapter {
    let id: ProviderID

    func probe() async -> ProviderSnapshot {
        .notConnected(id)
    }

    func preview(_ request: TriggerRequest) async throws -> TriggerReceipt {
        TriggerReceipt(id: UUID(), provider: id, occurredAt: .now, outcome: .previewed)
    }

    func trigger(_ request: TriggerRequest) async throws -> TriggerReceipt {
        throw IndeterminateTestError.connectionLost
    }
}
