public protocol ProviderAdapter: Sendable {
    var id: ProviderID { get }
    func probe() async -> ProviderSnapshot
    func preview(_ request: TriggerRequest) async throws -> TriggerReceipt
    func trigger(_ request: TriggerRequest) async throws -> TriggerReceipt
}
