protocol CodexStartRequesting: Sendable {
    func requestStart(prompt: String) async throws
}
