import Foundation

/// Decides whether a provider opened a new usage window between two readings.
///
/// A Start Now request is only confirmed by the provider's own figures, never
/// by the clock. Three signals count: an unstarted placeholder became a real
/// window, usage rose, or a session window's reset jumped past the one that
/// was open.
public struct UsageWindowStartDetector: Sendable {
    public init() {}

    public func windowStarted(
        baseline: [UsageWindow],
        current: [UsageWindow],
        provider: ProviderID
    ) -> Bool {
        startedWindow(baseline: baseline, current: current, provider: provider) != nil
    }

    /// The window that opened since the baseline reading, or nil when nothing
    /// did. The window a session opens is the session window when the plan
    /// has one; a plan that reports only a weekly cap opens that cap.
    public func startedWindow(
        baseline: [UsageWindow],
        current: [UsageWindow],
        provider: ProviderID
    ) -> UsageWindow? {
        let baselineWindows = trackedWindows(in: baseline, for: provider)
        let currentWindows = trackedWindows(in: current, for: provider)
        guard !currentWindows.isEmpty else { return nil }

        // A placeholder that pinned into a real window is the clearest signal:
        // usage may still round to zero after a one-word prompt.
        if let pinned = currentWindows.first(where: { window in
            guard !window.isUnstarted else { return false }
            let counterpart = baselineWindows.filter { $0.duration == window.duration }
            return !counterpart.isEmpty && counterpart.allSatisfy(\.isUnstarted)
        }) {
            return pinned
        }

        let startedBaseline = baselineWindows.filter { !$0.isUnstarted }
        if let latestBaselineReset = startedBaseline.map(\.resetsAt).max(),
           let latestCurrent = currentWindows
               .filter(\.isSessionWindow)
               .max(by: { $0.resetsAt < $1.resetsAt }),
           latestCurrent.resetsAt > latestBaselineReset.addingTimeInterval(60) {
            return latestCurrent
        }

        let baselineUsage = baselineWindows.compactMap(\.usedFraction).max()
        let currentUsage = currentWindows.compactMap(\.usedFraction).max()
        if let currentUsage, let baselineUsage, currentUsage > baselineUsage + 0.0001 {
            return currentWindows.max { ($0.usedFraction ?? 0) < ($1.usedFraction ?? 0) }
        }
        if currentUsage != nil, baselineUsage == nil, !baselineWindows.isEmpty {
            return currentWindows.first
        }
        return nil
    }

    /// Session windows when the provider reports any; otherwise every window
    /// it reports, which for a weekly-only plan is the weekly cap.
    private func trackedWindows(
        in windows: [UsageWindow],
        for provider: ProviderID
    ) -> [UsageWindow] {
        let providerWindows = windows.filter { $0.provider == provider }
        let sessions = providerWindows.filter(\.isSessionWindow)
        return sessions.isEmpty ? providerWindows : sessions
    }
}
