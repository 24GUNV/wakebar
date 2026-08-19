public enum ExecutionDeliveryState: String, Codable, Equatable, Sendable {
    case claimed
    case confirmed
    case failedBeforeSend
    case deliveryUnknown
}
