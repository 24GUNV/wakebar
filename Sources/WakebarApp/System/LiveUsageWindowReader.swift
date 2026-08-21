import Foundation
import WakebarCore

/// Reads live usage independently for each provider, preserving the log
/// reader as a provider-level fallback when credentials or the network fail.
/// Successful API readings are short-lived because the popover can refresh
/// more often than the provider limits can change.
actor LiveUsageWindowReader: UsageWindowReading, UsageWindowIssueReporting {
    private struct CacheEntry: Sendable {
        let windows: [UsageWindow]
        let issue: UsageWindowProviderIssue?
        let expiresAt: Date
    }

    private let codexClient: CodexUsageAPIClient
    private let claudeClient: ClaudeUsageAPIClient
    private let fallback: any UsageWindowReading
    private let cacheDuration: TimeInterval

    private var cache: [ProviderID: CacheEntry] = [:]
    private var issues: [ProviderID: UsageWindowProviderIssue] = [:]

    init(
        codexClient: CodexUsageAPIClient = CodexUsageAPIClient(),
        claudeClient: ClaudeUsageAPIClient = ClaudeUsageAPIClient(),
        fallback: any UsageWindowReading = SessionLogUsageWindowReader(),
        // A usage window turns over every five hours, so a reading minutes old
        // is still true to within a rounding error. The cost of a short cache is
        // not bandwidth but the macOS credential prompt each uncached Claude
        // read can raise: launching and then opening the menu was two prompts
        // for one unchanged answer.
        cacheDuration: TimeInterval = 5 * 60
    ) {
        self.codexClient = codexClient
        self.claudeClient = claudeClient
        self.fallback = fallback
        self.cacheDuration = cacheDuration
    }

    func currentWindows(now: Date) async -> [UsageWindow] {
        var windows: [UsageWindow] = []

        for provider in ProviderID.allCases {
            if let cached = cache[provider], cached.expiresAt > now {
                windows.append(contentsOf: cached.windows)
                setIssue(cached.issue, for: provider)
                continue
            }

            do {
                let liveWindows = try await liveWindows(for: provider, now: now)
                cache[provider] = CacheEntry(
                    windows: liveWindows,
                    issue: nil,
                    expiresAt: now.addingTimeInterval(cacheDuration)
                )
                windows.append(contentsOf: liveWindows)
                setIssue(nil, for: provider)
            } catch {
                let failure = issue(from: error, for: provider)
                cache[provider] = CacheEntry(
                    windows: [],
                    issue: failure,
                    expiresAt: now.addingTimeInterval(Self.retryDelay(after: failure))
                )
                setIssue(failure, for: provider)
            }
        }

        // A provider can answer with only a weekly cap. The logs may still hold
        // a session window it did not mention, so they are worth one look.
        let missingSession = ProviderID.allCases.filter { provider in
            !windows.contains { $0.provider == provider && $0.isSessionWindow && $0.isOpen(at: now) }
        }
        guard !missingSession.isEmpty else { return windows }

        let fallbackWindows = await fallback.currentWindows(now: now)
        for provider in missingSession {
            let providerWindows = fallbackWindows.filter { $0.provider == provider }
            // A provider that answered keeps its own reading — the API is
            // authoritative on what it did report — and takes only the session
            // window it was missing. One that said nothing takes the lot.
            let answered = windows.contains { $0.provider == provider }
            let recovered = answered ? providerWindows.filter(\.isSessionWindow) : providerWindows
            windows.append(contentsOf: recovered)

            if recovered.contains(where: { $0.isSessionWindow && $0.isOpen(at: now) }) {
                // The logs supplied what the call could not. Whatever went wrong
                // upstream cost the user nothing, so it is not worth a row.
                setIssue(nil, for: provider)
            } else if !answered, recovered.isEmpty, issues[provider] == nil {
                // Nothing from anywhere is worth explaining. A weekly cap and no
                // session window is not: the weekly row already says so in the
                // user's own terms, and repeating it invents a problem.
                setIssue(.noSessionWindowReported, for: provider)
            }
        }

        return windows
    }

    func currentUsageWindowIssues() async -> [ProviderID: UsageWindowProviderIssue] {
        issues
    }

    /// How long to believe a failure before asking the provider again.
    ///
    /// A refusal is not a hiccup. A denied credential prompt, a missing file or
    /// a rejected token stays true until the user does something about it, and
    /// retrying on the next popover open turns one refusal into a prompt on
    /// every click of the menu bar. A network error is the opposite: it is
    /// usually over by the time anyone looks again.
    private static func retryDelay(after issue: UsageWindowProviderIssue) -> TimeInterval {
        switch issue {
        case .network, .invalidResponse:
            60
        case .rateLimited:
            // Asking again in a minute is what earned the refusal. Backing off
            // costs a slightly stale reading and nothing else.
            5 * 60
        case .missingCredentials, .claudeOAuthCredentialMissing, .keychainUnavailable,
             .insufficientScope, .unauthorized, .noSessionWindowReported:
            15 * 60
        }
    }

    private func liveWindows(for provider: ProviderID, now: Date) async throws -> [UsageWindow] {
        switch provider {
        case .claude:
            try await claudeClient.currentWindows(now: now)
        case .codex:
            try await codexClient.currentWindows(now: now)
        }
    }

    private func setIssue(_ issue: UsageWindowProviderIssue?, for provider: ProviderID) {
        if let issue {
            issues[provider] = issue
        } else {
            issues.removeValue(forKey: provider)
        }
    }

    private func issue(from error: Error, for provider: ProviderID) -> UsageWindowProviderIssue {
        if let issue = error as? UsageWindowProviderIssue {
            return issue
        }
        guard let apiError = error as? UsageWindowAPIError else {
            return .network
        }
        switch apiError {
        case .network:
            return .network
        case .rateLimited:
            return .rateLimited
        case .unauthorized:
            return .unauthorized
        case .forbidden:
            // Claude issues usage-scoped tokens separately, so a refusal there
            // is worth naming. Codex has no equivalent split.
            return provider == .claude ? .insufficientScope : .unauthorized
        case .invalidResponse:
            return .invalidResponse
        }
    }
}
