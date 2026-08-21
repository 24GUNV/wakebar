public struct ClaudeRoutineCapability: Equatable, Sendable {
    public enum ProvisioningControl: Equatable, Sendable {
        case userManaged
        case claudeCLIAssisted
    }

    public enum TriggerAPIStability: Equatable, Sendable {
        case experimental(betaHeader: String)
    }

    public let runsWhenMacIsOff: Bool
    public let provisioningControl: ProvisioningControl
    public let triggerAPIStability: TriggerAPIStability
    public let minimumRecurringIntervalMinutes: Int
    public let scheduledStartCanBeDelayed: Bool

    public static let current = Self(
        runsWhenMacIsOff: true,
        provisioningControl: .claudeCLIAssisted,
        triggerAPIStability: .experimental(betaHeader: "experimental-cc-routine-2026-04-01"),
        minimumRecurringIntervalMinutes: 60,
        scheduledStartCanBeDelayed: true
    )

    public var setupStatusText: String {
        switch provisioningControl {
        case .userManaged:
            "Create or edit this Routine in Claude"
        case .claudeCLIAssisted:
            "Wakebar starts the official Claude Code setup flow"
        }
    }

    public var timingStatusText: String {
        "Runs in Claude's cloud; the start can be a few minutes late"
    }
}
