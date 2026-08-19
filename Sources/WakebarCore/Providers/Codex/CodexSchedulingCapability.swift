public struct CodexSchedulingCapability: Identifiable, Equatable, Sendable {
    public let route: CodexSchedulingRoute
    public let status: CodexCapabilityStatus
    public let hostRequirement: CodexHostRequirement
    public let scheduleManager: CodexScheduleManager
    public let canAccessLocalProjectFiles: Bool
    public let usageWindowEffect: CodexUsageWindowEffect

    public var id: CodexSchedulingRoute { route }

    public init(
        route: CodexSchedulingRoute,
        status: CodexCapabilityStatus,
        hostRequirement: CodexHostRequirement,
        scheduleManager: CodexScheduleManager,
        canAccessLocalProjectFiles: Bool,
        usageWindowEffect: CodexUsageWindowEffect = .unverified
    ) {
        self.route = route
        self.status = status
        self.hostRequirement = hostRequirement
        self.scheduleManager = scheduleManager
        self.canAccessLocalProjectFiles = canAccessLocalProjectFiles
        self.usageWindowEffect = usageWindowEffect
    }
}
