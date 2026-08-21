import WakebarCore

protocol UsageWindowIssueReporting: Sendable {
    func currentUsageWindowIssues() async -> [ProviderID: UsageWindowProviderIssue]
}
