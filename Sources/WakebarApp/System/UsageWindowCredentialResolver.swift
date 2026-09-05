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
        /// The item exists but reading it needs the user's consent dialog,
        /// and the caller asked for a quiet read (or the user declined).
        case interactionRequired
        case unavailable
    }

    enum SecurityCLIRunResult: Sendable {
        case completed(stdout: Data, exitCode: Int32)
        case timedOut
        case launchFailed
    }

    private let environment: [String: String]
    private let homeDirectory: URL
    /// Injected so tests can answer without querying the real Keychain. The
    /// live query prompts the user for access, which a test run must never do.
    private let keychainLookup: @Sendable (_ allowUI: Bool) -> KeychainResult
    /// Injected so tests never launch `security` or read the real Keychain.
    private let securityCLIRunner: @Sendable () -> SecurityCLIRunResult

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        keychainLookup: (@Sendable (_ allowUI: Bool) -> KeychainResult)? = nil,
        securityCLIRunner: (@Sendable () -> SecurityCLIRunResult)? = nil
    ) {
        self.environment = environment
        self.homeDirectory = homeDirectory
        self.keychainLookup = keychainLookup ?? Self.claudeCodeKeychainCredentials
        if let securityCLIRunner {
            self.securityCLIRunner = securityCLIRunner
        } else if keychainLookup != nil {
            self.securityCLIRunner = { .launchFailed }
        } else {
            self.securityCLIRunner = Self.runClaudeCodeSecurityCLI
        }
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

        // Claude Code writes this item with the `security` tool, and macOS lets
        // the tool that created an item read it back without a dialog — that is
        // how the CLI itself reads it on every launch. The tool is judged by its
        // own identity, not by the app that spawned it, so a read through it is
        // quiet whichever intent asked. A read through the Security framework is
        // judged by Wakebar's identity instead, which the item's ACL does not
        // list, so it either prompts or fails. The tool therefore goes first for
        // every read; the framework is only the fallback, and a background
        // fallback must fail quietly rather than raise the dialog.
        let keychainResult: KeychainResult
        switch securityCLIRunner() {
        case .completed(let stdout, 0):
            let data = Self.decodedSecurityCLIOutput(stdout)
            if (try? JSONDecoder().decode(ClaudeCredentialsPayload.self, from: data)) != nil {
                keychainResult = .data(data)
            } else {
                keychainResult = keychainLookup(allowUI)
            }
        case .completed(_, 44):
            keychainResult = .notFound
        case .completed, .timedOut, .launchFailed:
            keychainResult = keychainLookup(allowUI)
        }

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

    private static func runClaudeCodeSecurityCLI() -> SecurityCLIRunResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/security")
        process.arguments = [
            "find-generic-password",
            "-s", "Claude Code-credentials",
            "-w",
        ]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            return .launchFailed
        }

        let deadline = Date.now.addingTimeInterval(5)
        while process.isRunning {
            if Date.now >= deadline {
                process.terminate()
                return .timedOut
            }
            Thread.sleep(forTimeInterval: 0.01)
        }

        let stdout = standardOutput.fileHandleForReading.readDataToEndOfFile()
        _ = standardError.fileHandleForReading.readDataToEndOfFile()
        return .completed(stdout: stdout, exitCode: process.terminationStatus)
    }

    private static func decodedSecurityCLIOutput(_ output: Data) -> Data {
        let withoutLeadingWhitespace = output.drop { $0.isASCIIWhitespace }
        let trimmed = Data(
            withoutLeadingWhitespace.reversed().drop { $0.isASCIIWhitespace }.reversed()
        )
        guard !trimmed.isEmpty, trimmed.count.isMultiple(of: 2) else {
            return trimmed
        }

        var decoded = Data(capacity: trimmed.count / 2)
        var index = trimmed.startIndex
        while index < trimmed.endIndex {
            let nextIndex = trimmed.index(after: index)
            guard nextIndex < trimmed.endIndex,
                  let high = hexNibble(trimmed[index]),
                  let low = hexNibble(trimmed[nextIndex])
            else {
                return trimmed
            }
            decoded.append((high << 4) | low)
            index = trimmed.index(after: nextIndex)
        }

        return decoded.first == 0x7B ? decoded : trimmed
    }

    private static func hexNibble(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 0x30...0x39:
            byte - 0x30
        case 0x41...0x46:
            byte - 0x41 + 10
        case 0x61...0x66:
            byte - 0x61 + 10
        default:
            nil
        }
    }

    private static func claudeCodeKeychainCredentials(allowUI: Bool) -> KeychainResult {
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

private extension UInt8 {
    var isASCIIWhitespace: Bool {
        switch self {
        case 0x09...0x0D, 0x20:
            true
        default:
            false
        }
    }
}
