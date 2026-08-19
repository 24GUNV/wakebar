public protocol ClaudeRoutineCredentialStore: Sendable {
    /// Returns a per-Routine bearer token from local secure storage.
    /// Implementations must not synchronize or upload the token to a Wakebar service.
    func bearerToken(for reference: ClaudeRoutineCredentialReference) async throws -> String?
}
