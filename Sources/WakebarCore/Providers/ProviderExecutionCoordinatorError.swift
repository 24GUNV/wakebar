public enum ProviderExecutionCoordinatorError: Error, Equatable, Sendable {
    case alarmEventCannotUseProviderAdapter
    case providerMismatch
    case missingLedgerRecord
}
