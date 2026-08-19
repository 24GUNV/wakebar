import Foundation

public struct ClaudeRoutineProvisioningPlan: Equatable, Sendable {
    public let capability: ClaudeRoutineCapability
    public let managementURL: URL
    public let routineName: String
    public let savedPrompt: String
    public let hour: Int
    public let minute: Int
    public let weekdays: Set<Weekday>
    public let timeZoneIdentifier: String
    public let userActions: [String]
    public let limitations: [String]
}
