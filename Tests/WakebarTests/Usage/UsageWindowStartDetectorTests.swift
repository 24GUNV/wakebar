import Foundation
import Testing
@testable import WakebarCore

struct UsageWindowStartDetectorTests {
    private let detector = UsageWindowStartDetector()
    private let now = Date(timeIntervalSince1970: 1_787_500_000)

    @Test
    func detectsLaterResetForSelectedProvider() {
        let baseline = window(provider: .claude, resetOffset: 60 * 60, usedFraction: 0.2)
        let current = window(provider: .claude, resetOffset: 5 * 60 * 60, usedFraction: 0)

        #expect(detector.windowStarted(baseline: [baseline], current: [current], provider: .claude))
        #expect(!detector.windowStarted(baseline: [baseline], current: [current], provider: .codex))
    }

    @Test
    func detectsIncreasedUsageWithoutResetChange() {
        let baseline = window(provider: .codex, resetOffset: 60 * 60, usedFraction: 0.2)
        let current = window(provider: .codex, resetOffset: 60 * 60, usedFraction: 0.3)

        #expect(detector.windowStarted(baseline: [baseline], current: [current], provider: .codex))
    }

    @Test
    func ignoresWeeklyAndUnchangedWindows() {
        let baseline = window(provider: .claude, resetOffset: 60 * 60, usedFraction: 0.2)
        let unchanged = window(provider: .claude, resetOffset: 60 * 60, usedFraction: 0.2)
        let weekly = UsageWindow(
            provider: .claude,
            duration: 7 * 24 * 60 * 60,
            resetsAt: now.addingTimeInterval(6 * 24 * 60 * 60),
            usedFraction: 0.8,
            observedAt: now,
            confidence: .reported
        )

        #expect(!detector.windowStarted(
            baseline: [baseline],
            current: [unchanged, weekly],
            provider: .claude
        ))
    }

    private func window(
        provider: ProviderID,
        resetOffset: TimeInterval,
        usedFraction: Double
    ) -> UsageWindow {
        UsageWindow(
            provider: provider,
            duration: 5 * 60 * 60,
            resetsAt: now.addingTimeInterval(resetOffset),
            usedFraction: usedFraction,
            observedAt: now,
            confidence: .reported
        )
    }
}
