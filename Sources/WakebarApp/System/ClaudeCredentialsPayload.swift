struct ClaudeCredentialsPayload: Decodable {
    let claudeAiOauth: ClaudeOAuthCredentialPayload?
    let mcpOAuth: ClaudeOAuthCredentialPayload?
}
