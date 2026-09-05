import Foundation

/// The single source of the Claude credential for the whole app. Every client
/// shares this actor so one Keychain read serves all of them, and concurrent
/// callers join the same read instead of racing to open their own prompts.
actor ClaudeCredentialStore {
    static let shared = ClaudeCredentialStore()

    /// A token is refreshed by the CLI before it expires, so a reading this
    /// close to expiry is worth replacing even though it may still work.
    private static let expiryMargin: TimeInterval = 5 * 60
    /// A credential with no expiry date cannot be trusted forever; the CLI
    /// may rotate it underneath us without the store noticing.
    private static let unknownExpiryLifetime: TimeInterval = 15 * 60
    /// How long a server-rejected token stays refused. Re-reading the Keychain
    /// and resending the same rejected token is a loop, not a retry.
    private static let rejectionBackoff: TimeInterval = 15 * 60

    private let resolver: UsageWindowCredentialResolver
    private let now: @Sendable () -> Date

    private var cached: (credential: ClaudeCredential, fetchedAt: Date)?
    private var inFlightQuiet: Task<ClaudeCredential, Error>?
    private var inFlightPrompting: Task<ClaudeCredential, Error>?
    private var rejection: (token: String, until: Date)?

    init(
        resolver: UsageWindowCredentialResolver = UsageWindowCredentialResolver(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.resolver = resolver
        self.now = now
    }

    func credential(_ intent: ClaudeCredentialIntent) async throws -> ClaudeCredential {
        do {
            try resolver.requireConsent(for: .claude)
        } catch {
            cached = nil
            throw error
        }
        let asked = now()
        if let cached, isUsable(cached, at: asked) {
            return cached.credential
        }

        // A prompting read satisfies anyone; a quiet read must not stand in
        // for a user action, which is entitled to raise the dialog.
        if let inFlightPrompting {
            return try await inFlightPrompting.value
        }
        if intent == .background, let inFlightQuiet {
            return try await inFlightQuiet.value
        }

        let allowUI = intent == .userInitiated
        let resolver = resolver
        // Detached because a granted dialog can hold SecItemCopyMatching open
        // for as long as the user takes to answer it.
        let read = Task.detached(priority: .userInitiated) {
            try resolver.claudeCredential(allowUI: allowUI)
        }
        if allowUI {
            inFlightPrompting = read
        } else {
            inFlightQuiet = read
        }
        defer {
            if allowUI {
                inFlightPrompting = nil
            } else {
                inFlightQuiet = nil
            }
        }

        let credential: ClaudeCredential
        do {
            credential = try await read.value
        } catch {
            cached = nil
            throw error
        }

        if let rejection {
            if rejection.token != credential.accessToken || asked >= rejection.until {
                self.rejection = nil
            } else if intent == .background {
                // The Keychain still holds the token the server refused.
                // Failing here keeps the backoff; a user action may retry.
                throw UsageWindowProviderIssue.unauthorized
            }
        }

        cached = (credential, asked)
        return credential
    }

    /// Called when the server rejects a token. Only the generation that was
    /// rejected is dropped; a token refreshed in the meantime is kept.
    func invalidate(tokenMatching token: String) {
        guard cached?.credential.accessToken == token else { return }
        cached = nil
        rejection = (token, now().addingTimeInterval(Self.rejectionBackoff))
    }

    private func isUsable(
        _ entry: (credential: ClaudeCredential, fetchedAt: Date),
        at date: Date
    ) -> Bool {
        guard date < entry.fetchedAt.addingTimeInterval(Self.unknownExpiryLifetime) else { return false }
        if let expiresAt = entry.credential.expiresAt {
            return date < expiresAt.addingTimeInterval(-Self.expiryMargin)
        }
        return date < entry.fetchedAt.addingTimeInterval(Self.unknownExpiryLifetime)
    }
}
