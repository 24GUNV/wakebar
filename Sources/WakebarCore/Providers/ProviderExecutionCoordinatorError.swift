public enum ProviderExecutionCoordinatorError: Error, Equatable, Sendable {
    case providerMismatch
    case missingLedgerRecord
}
