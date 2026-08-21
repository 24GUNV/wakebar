import Foundation
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
        case unavailable
    }

    private let environment: [String: String]
    private let homeDirectory: URL
    /// Injected so tests can answer without querying the real Keychain. The
    /// live query prompts the user for access, which a test run must never do.
    private let keychainLookup: @Sendable () -> KeychainResult

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        keychainLookup: (@Sendable () -> KeychainResult)? = nil
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

    func claudeAccessToken() throws -> String {
        let path = path(
            environmentVariable: "CLAUDE_CONFIG_DIR",
            fallback: homeDirectory.appendingPathComponent(".claude")
        ).appendingPathComponent(".credentials.json")

        var fileHasOnlyMCPAuthentication = false
        if let data = try? Data(contentsOf: path),
           let credentials = try? JSONDecoder().decode(ClaudeCredentials.self, from: data) {
            if let accessToken = credentials.claudeAiOauth?.accessToken,
               !accessToken.isEmpty {
                return accessToken
            }
            fileHasOnlyMCPAuthentication = credentials.mcpOAuth != nil
        }

        switch keychainLookup() {
        case .data(let data):
            guard let credentials = try? JSONDecoder().decode(ClaudeCredentials.self, from: data) else {
                throw fileHasOnlyMCPAuthentication
                    ? UsageWindowProviderIssue.claudeOAuthCredentialMissing
                    : UsageWindowProviderIssue.missingCredentials
            }
            if let accessToken = credentials.claudeAiOauth?.accessToken,
               !accessToken.isEmpty {
                return accessToken
            }
            if credentials.mcpOAuth != nil || fileHasOnlyMCPAuthentication {
                throw UsageWindowProviderIssue.claudeOAuthCredentialMissing
            }
            throw UsageWindowProviderIssue.missingCredentials
        case .notFound:
            throw fileHasOnlyMCPAuthentication
                ? UsageWindowProviderIssue.claudeOAuthCredentialMissing
                : UsageWindowProviderIssue.missingCredentials
        case .unavailable:
            throw UsageWindowProviderIssue.keychainUnavailable
        }
    }

    private func path(environmentVariable: String, fallback: URL) -> URL {
        guard let value = environment[environmentVariable], !value.isEmpty else {
            return fallback
        }
        return URL(fileURLWithPath: value)
    }

    private static func claudeCodeKeychainCredentials() -> KeychainResult {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return .data(data)
        }
        if status == errSecItemNotFound {
            return .notFound
        }
        return .unavailable
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

    private struct ClaudeCredentials: Decodable {
        let claudeAiOauth: ClaudeOAuth?
        let mcpOAuth: ClaudeOAuth?

        enum CodingKeys: String, CodingKey {
            case claudeAiOauth
            case mcpOAuth
        }
    }

    private struct ClaudeOAuth: Decodable {
        let accessToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken
        }
    }
}
