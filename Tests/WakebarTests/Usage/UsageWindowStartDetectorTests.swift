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

    /// Codex reports an idle weekly cap as a full, unused week whose reset
    /// keeps pace with the clock. A wake pins it. Usage still rounds to zero.
    @Test
    func detectsAWeeklyPlaceholderPinningIntoARealWindow() {
        let week: TimeInterval = 7 * 24 * 60 * 60
        let placeholder = UsageWindow(
            provider: .codex,
            duration: week,
            resetsAt: now.addingTimeInterval(week),
            usedFraction: 0,
            observedAt: now,
            confidence: .reported
        )
        let later = now.addingTimeInterval(5 * 60)
        let stillIdle = UsageWindow(
            provider: .codex,
            duration: week,
            resetsAt: later.addingTimeInterval(week),
            usedFraction: 0,
            observedAt: later,
            confidence: .reported
        )
        let pinned = UsageWindow(
            provider: .codex,
            duration: week,
            resetsAt: now.addingTimeInterval(week + 60),
            usedFraction: 0,
            observedAt: later,
            confidence: .reported
        )

        #expect(detector.startedWindow(baseline: [placeholder], current: [stillIdle], provider: .codex) == nil)
        #expect(detector.startedWindow(baseline: [placeholder], current: [pinned], provider: .codex) == pinned)
    }

    @Test
    func unstartedIsAFullUnusedWindowWhoseResetTracksTheClock() {
        let idle = window(provider: .codex, resetOffset: 5 * 60 * 60 - 30, usedFraction: 0)
        let started = window(provider: .codex, resetOffset: 5 * 60 * 60 - 10 * 60, usedFraction: 0)
        let used = window(provider: .codex, resetOffset: 5 * 60 * 60, usedFraction: 0.01)

        #expect(idle.isUnstarted)
        #expect(!started.isUnstarted)
        #expect(!used.isUnstarted)
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
