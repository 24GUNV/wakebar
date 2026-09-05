import Foundation
import Security
import WakebarCore

/// Resolves the CLIs' existing credentials without modifying or exporting
/// them. The CLIs remain the owners of both credential files.
struct UsageWindowCredentialResolver: Sendable {
    struct CodexCredential: Sendable {
        let accessToken: String
        let accountID: String
    }

    enum KeychainResult: Sendable {
        case data(Data)
        case notFound
        /// The item exists but reading it needs the user's consent dialog,
        /// and the caller asked for a quiet read (or the user declined).
        case interactionRequired
        case unavailable
    }

    private let environment: [String: String]
    private let homeDirectory: URL
    /// Injected so tests can answer without querying the real Keychain. The
    /// live query prompts the user for access, which a test run must never do.
    private let keychainLookup: @Sendable (_ allowUI: Bool) -> KeychainResult
    private let accessAllowed: @Sendable (ProviderID) -> Bool

    init(
        accessAllowed: @escaping @Sendable (ProviderID) -> Bool = { ProviderConnectionConsent.isAllowed($0) },
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        keychainLookup: (@Sendable (_ allowUI: Bool) -> KeychainResult)? = nil
    ) {
        self.accessAllowed = accessAllowed
        self.environment = environment
        self.homeDirectory = homeDirectory
        self.keychainLookup = keychainLookup ?? Self.claudeCodeKeychainCredentials
    }

    func requireConsent(for provider: ProviderID) throws {
        guard accessAllowed(provider) else { throw UsageWindowProviderIssue.connectionRequired }
    }

    func codexCredential() throws -> CodexCredential {
        try requireConsent(for: .codex)
        let path = path(
            environmentVariable: "CODEX_HOME",
            fallback: homeDirectory.appendingPathComponent(".codex")
        ).appendingPathComponent("auth.json")

        guard let data = try? Data(contentsOf: path),
              let auth = try? JSONDecoder().decode(CodexAuth.self, from: data),
              let accessToken = auth.resolvedAccessToken,
              !accessToken.isEmpty,
              let accountID = auth.resolvedAccountID,
              !accountID.isEmpty
        else {
            throw UsageWindowProviderIssue.missingCredentials
        }

        return CodexCredential(accessToken: accessToken, accountID: accountID)
    }

    func claudeCredential(allowUI: Bool = true) throws -> ClaudeCredential {
        try requireConsent(for: .claude)
        let path = path(
            environmentVariable: "CLAUDE_CONFIG_DIR",
            fallback: homeDirectory.appendingPathComponent(".claude")
        ).appendingPathComponent(".credentials.json")

        var fileHasOnlyMCPAuthentication = false
        if let data = try? Data(contentsOf: path),
           let credentials = try? JSONDecoder().decode(ClaudeCredentialsPayload.self, from: data) {
            if let accessToken = credentials.claudeAiOauth?.accessToken,
               !accessToken.isEmpty {
                return Self.credential(accessToken: accessToken, payload: credentials.claudeAiOauth)
            }
            fileHasOnlyMCPAuthentication = credentials.mcpOAuth != nil
        }

        // Use Wakebar's identity for Keychain authorization. A background
        // read fails quietly when access has not been granted by macOS.
        let keychainResult = keychainLookup(allowUI)

        switch keychainResult {
        case .data(let data):
            guard let credentials = try? JSONDecoder().decode(ClaudeCredentialsPayload.self, from: data) else {
                throw fileHasOnlyMCPAuthentication
                    ? UsageWindowProviderIssue.claudeOAuthCredentialMissing
                    : UsageWindowProviderIssue.missingCredentials
            }
            if let accessToken = credentials.claudeAiOauth?.accessToken,
               !accessToken.isEmpty {
                return Self.credential(accessToken: accessToken, payload: credentials.claudeAiOauth)
            }
            if credentials.mcpOAuth != nil || fileHasOnlyMCPAuthentication {
                throw UsageWindowProviderIssue.claudeOAuthCredentialMissing
            }
            throw UsageWindowProviderIssue.missingCredentials
        case .notFound:
            throw fileHasOnlyMCPAuthentication
                ? UsageWindowProviderIssue.claudeOAuthCredentialMissing
                : UsageWindowProviderIssue.missingCredentials
        case .interactionRequired:
            throw UsageWindowProviderIssue.keychainAuthorizationRequired
        case .unavailable:
            throw UsageWindowProviderIssue.keychainUnavailable
        }
    }

    func claudeAccessToken() throws -> String {
        try claudeCredential().accessToken
    }

    private func path(environmentVariable: String, fallback: URL) -> URL {
        guard let value = environment[environmentVariable], !value.isEmpty else {
            return fallback
        }
        return URL(fileURLWithPath: value)
    }

    private static let keychainLock = NSLock()

    private static func claudeCodeKeychainCredentials(allowUI: Bool) -> KeychainResult {
        keychainLock.lock()
        defer { keychainLock.unlock() }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if !allowUI {
            // The item lives in the login keychain, whose access dialog answers
            // only to the process-wide interaction switch. An `LAContext` with
            // `interactionNotAllowed` governs data-protection items and leaves
            // this dialog alone: securityd logged "displaying keychain prompt"
            // for every background read made that way. With the switch off the
            // read fails with errSecAuthFailed instead of prompting.
            return withUserInteractionDisabled { copyMatching(query) }
        }
        return copyMatching(query)
    }

    /// `SecKeychainSetUserInteractionAllowed` is deprecated, but it remains the
    /// only switch the login keychain honours. It is process-wide, so it is held
    /// for one read and restored on the way out.
    private static func withUserInteractionDisabled(
        _ body: () -> KeychainResult
    ) -> KeychainResult {
        var wasAllowed: DarwinBoolean = true
        SecKeychainGetUserInteractionAllowed(&wasAllowed)
        SecKeychainSetUserInteractionAllowed(false)
        defer { SecKeychainSetUserInteractionAllowed(wasAllowed.boolValue) }
        return body()
    }

    private static func copyMatching(_ query: [String: Any]) -> KeychainResult {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return .data(data)
        }
        switch status {
        case errSecItemNotFound:
            return .notFound
        case errSecInteractionNotAllowed, errSecUserCanceled, errSecAuthFailed:
            // A declined dialog and a suppressed one mean the same thing to
            // callers: the item exists but the user has not let us read it.
            return .interactionRequired
        default:
            return .unavailable
        }
    }

    private static func credential(
        accessToken: String,
        payload: ClaudeOAuthCredentialPayload?
    ) -> ClaudeCredential {
        ClaudeCredential(
            accessToken: accessToken,
            expiresAt: payload?.expiresAt,
            hasRefreshToken: !(payload?.refreshToken?.isEmpty ?? true)
        )
    }

    private struct CodexAuth: Decodable {
        let tokens: CodexTokens?
        let accessToken: String?
        let accountID: String?

        var resolvedAccessToken: String? { tokens?.accessToken ?? accessToken }
        var resolvedAccountID: String? { tokens?.accountID ?? accountID }

        enum CodingKeys: String, CodingKey {
            case tokens
            case accessToken = "access_token"
            case accountID = "account_id"
        }
    }

    private struct CodexTokens: Decodable {
        let accessToken: String?
        let accountID: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case accountID = "account_id"
        }
    }

}
