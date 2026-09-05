protocol CodexStartRequesting: Sendable {
    func requestStart(prompt: String) async throws -> CodexStartRequestOutcome
}
