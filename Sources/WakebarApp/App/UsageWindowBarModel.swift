import Foundation
import WakebarCore

struct UsageWindowBarModel: Equatable, Identifiable {
    let provider: ProviderID
    let limitKind: UsageLimitKind
    let usedFraction: Double?
    let usedText: String
    let resetText: String

    var id: String {
        "\(provider.rawValue)-\(limitKind.rawValue)"
    }

    var label: String {
        switch limitKind {
        case .session:
            "Five-hour"
        case .weekly:
            "Weekly"
        case .weeklyFable:
            "Fable weekly"
        }
    }

    init(window: UsageWindow, now: Date) {
        provider = window.provider
        limitKind = window.limitKind
        usedFraction = window.usedFraction.map { min(max($0, 0), 1) }
        if let usedFraction {
            usedText = "\(Int((usedFraction * 100).rounded()))% used"
        } else {
            usedText = "Usage not reported"
        }
        resetText = "resets \(UsageSummaryViewModel.relativeTime(from: now, to: window.resetsAt))"
    }

    init(unreportedProvider provider: ProviderID) {
        self.provider = provider
        limitKind = .session
        usedFraction = nil
        usedText = "Usage not reported"
        resetText = "reset not reported"
    }
}
