import Foundation

public struct UsageWindowStartDetector: Sendable {
    public init() {}

    public func windowStarted(
        baseline: [UsageWindow],
        current: [UsageWindow],
        provider: ProviderID
    ) -> Bool {
        let baselineSessions = sessionWindows(in: baseline, for: provider)
        let currentSessions = sessionWindows(in: current, for: provider)
        guard !currentSessions.isEmpty else { return false }

        let latestBaselineReset = baselineSessions.map(\.resetsAt).max()
        if let latestCurrentReset = currentSessions.map(\.resetsAt).max() {
            if let latestBaselineReset {
                if latestCurrentReset > latestBaselineReset.addingTimeInterval(60) {
                    return true
                }
            } else {
                return true
            }
        }

        let baselineUsage = baselineSessions.compactMap(\.usedFraction).max()
        let currentUsage = currentSessions.compactMap(\.usedFraction).max()
        if let currentUsage, let baselineUsage {
            return currentUsage > baselineUsage + 0.0001
        }
        return currentUsage != nil && baselineUsage == nil
    }

    private func sessionWindows(
        in windows: [UsageWindow],
        for provider: ProviderID
    ) -> [UsageWindow] {
        windows.filter { $0.provider == provider && $0.isSessionWindow }
    }
}
