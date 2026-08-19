import Foundation

public struct CodexPreviewProviderAdapter: ProviderAdapter {
    public let id: ProviderID = .codex

    public init() {}

    public func probe() async -> ProviderSnapshot {
        ProviderSnapshot(
            provider: .codex,
            availability: .unavailable("Experimental preview only"),
            fiveHourRemaining: nil,
            fiveHourReset: nil,
            weeklyRemaining: nil,
            weeklyReset: nil
        )
    }

    public func preview(_ request: TriggerRequest) async throws -> TriggerReceipt {
        _ = try CodexCLIPreviewPlan(prompt: request.prompt)

        return TriggerReceipt(
            id: UUID(),
            provider: .codex,
            occurredAt: .now,
            outcome: .previewed
        )
    }

    public func trigger(_ request: TriggerRequest) async throws -> TriggerReceipt {
        _ = request
        throw ProviderAdapterError.liveExecutionNotConfigured
    }
}
