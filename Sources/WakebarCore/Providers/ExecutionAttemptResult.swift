public enum ExecutionAttemptResult: Equatable, Sendable {
    case confirmed(TriggerReceipt)
    case skippedDuplicate(ExecutionRecord)
    case failedBeforeSend(String)
    case deliveryUnknown(String)
}
