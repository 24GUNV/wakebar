/// Why the credential is being read. Background reads must never raise the
/// macOS Keychain dialog; only a read tied to an explicit user action may.
enum ClaudeCredentialIntent: Equatable, Sendable {
    case background
    case userInitiated
}
