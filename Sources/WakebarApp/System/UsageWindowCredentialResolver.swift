import Foundation
import LocalAuthentication
import Security

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

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        keychainLookup: (@Sendable (_ allowUI: Bool) -> KeychainResult)? = nil
    ) {
        self.environment = environment
        self.homeDirectory = homeDirectory
        self.keychainLookup = keychainLookup ?? Self.claudeCodeKeychainCredentials
    }

    func codexCredential() throws -> CodexCredential {
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

        switch keychainLookup(allowUI) {
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

    private static func claudeCodeKeychainCredentials(allowUI: Bool) -> KeychainResult {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if !allowUI {
            // Background reads must fail with errSecInteractionNotAllowed
            // instead of raising the consent dialog at a random moment.
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = context
        }

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
