import Foundation
import WakebarCore

struct UsageSummaryViewModel: Equatable {
    let nextWindowText: String
    let providers: [UsageProviderPresentation]

    init(
        enabledProviders: [ProviderID],
        events: [ScheduledEvent],
        windows: [UsageWindow],
        issues: [ProviderID: UsageWindowProviderIssue],
        now: Date
    ) {
        let nextStart = events
            .filter { $0.date > now }
            .map(\.date)
            .min()
        let hasOpenWindow = windows.contains { window in
            enabledProviders.contains(window.provider)
                && window.provider == .claude
                && window.isSessionWindow
                && window.isOpen(at: now)
        }

        if let nextStart {
            nextWindowText = "Next window: \(Self.relativeTime(from: now, to: nextStart))"
        } else if hasOpenWindow {
            nextWindowText = "Next window: now"
        } else {
            nextWindowText = "Next window: not scheduled"
        }

        providers = enabledProviders.map { provider in
            let providerWindows = windows
                .filter { $0.provider == provider && $0.isOpen(at: now) }
            let session = providerWindows
                .filter(\.isSessionWindow)
                .min { $0.resetsAt < $1.resetsAt }
            let weekly = providerWindows
                .filter { !$0.isSessionWindow }
                .sorted { lhs, rhs in
                    Self.limitOrder(lhs.limitKind) < Self.limitOrder(rhs.limitKind)
                }
            let sessionBars: [UsageWindowBarModel]
            if provider == .claude {
                sessionBars = [
                    session.map { UsageWindowBarModel(window: $0, now: now) }
                        ?? UsageWindowBarModel(unreportedProvider: provider),
                ]
            } else {
                sessionBars = []
            }
            let weeklyBars = weekly.map { UsageWindowBarModel(window: $0, now: now) }
            let bars = sessionBars + weeklyBars
            let issueMessage = bars.isEmpty
                ? issues[provider]?.message(for: provider)
                : nil
            return UsageProviderPresentation(
                provider: provider,
                bars: bars,
                issueMessage: issueMessage
            )
        }
    }

    private static func limitOrder(_ kind: UsageLimitKind) -> Int {
        switch kind {
        case .session:
            0
        case .weekly:
            1
        case .weeklyFable:
            2
        }
    }

    static func relativeTime(from now: Date, to date: Date) -> String {
        let remaining = max(0, date.timeIntervalSince(now))
        guard remaining >= 60 else { return "now" }

        let totalMinutes = Int(remaining / 60)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return hours > 0 ? "in \(days)d \(hours)h" : "in \(days)d"
        }
        if hours > 0 {
            return minutes > 0 ? "in \(hours)h \(minutes)m" : "in \(hours)h"
        }
        return "in \(minutes)m"
    }
}
