public struct CodexUsageWindowEffect: Equatable, Sendable {
    public let isVerified: Bool
    public let detail: String

    private init(isVerified: Bool, detail: String) {
        self.isVerified = isVerified
        self.detail = detail
    }

    /// Official OpenAI documentation does not establish that a small scheduled
    /// run starts or resets a five-hour or weekly subscription window.
    public static let unverified = Self(
        isVerified: false,
        detail: "A completed prompt confirms only that Codex ran. It does not confirm that a five-hour or weekly usage window started or reset."
    )
}
