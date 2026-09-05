import Foundation
import WakebarCore

struct ProviderStartNowCoordinator: Sendable {
    private let usageReaders: [ProviderID: any ProviderUsageReading]
    private let claudeRequester: any ClaudeStartRequesting
    private let codexRequester: any CodexStartRequesting
    private let sleeper: any UsageWindowPollingSleeping
    private let startDetector: UsageWindowStartDetector
    private let now: @Sendable () -> Date
    private let pollCount: Int
    private let pollInterval: TimeInterval

    init(
        usageReaders: [ProviderID: any ProviderUsageReading] = [
            // Start Now is a click, so its polling may raise the Keychain
            // dialog once if consent is still missing.
            .claude: ClaudeUsageAPIClient(credentialIntent: .userInitiated),
            .codex: CodexUsageAPIClient(),
        ],
        claudeRequester: any ClaudeStartRequesting = ClaudeRoutineStartRequester(),
        codexRequester: any CodexStartRequesting = CodexPingClient(),
        sleeper: any UsageWindowPollingSleeping = ContinuousClockUsageWindowPollingSleeper(),
        startDetector: UsageWindowStartDetector = UsageWindowStartDetector(),
        now: @escaping @Sendable () -> Date = { .now },
        pollCount: Int = 10,
        pollInterval: TimeInterval = 30
    ) {
        self.usageReaders = usageReaders
        self.claudeRequester = claudeRequester
        self.codexRequester = codexRequester
        self.sleeper = sleeper
        self.startDetector = startDetector
        self.now = now
        self.pollCount = pollCount
        self.pollInterval = pollInterval
    }

    func requestStart(
        for provider: ProviderID,
        schedule: WakeSchedule
    ) async throws -> ProviderStartNowOutcome {
        guard let usageReader = usageReaders[provider] else {
            throw ProviderStartNowError.unavailable
        }

        let baseline = try? await usageReader.currentWindows(now: now())
        switch provider {
        case .claude:
            try await claudeRequester.requestStart(for: schedule)
        case .codex:
            _ = try await codexRequester.requestStart(prompt: provider.minimalPrompt)
        }

        for _ in 0..<pollCount {
            try await sleeper.sleep(for: .seconds(pollInterval))
            let observedAt = now()
            guard let current = try? await usageReader.currentWindows(now: observedAt),
                  let baseline
            else { continue }
            if let confirmed = startDetector.startedWindow(
                baseline: baseline,
                current: current,
                provider: provider
            ) {
                return .started(confirmed)
            }
        }
        return .unconfirmed
    }
}
