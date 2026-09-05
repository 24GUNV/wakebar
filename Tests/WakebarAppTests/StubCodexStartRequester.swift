#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

actor StubCodexStartRequester: CodexStartRequesting {
    private(set) var prompts: [String] = []
    private let error: (any Error)?

    init(error: (any Error)? = nil) {
        self.error = error
    }

    func requestStart(prompt: String) async throws -> CodexStartRequestOutcome {
        prompts.append(prompt)
        if let error { throw error }
        return .sent
    }
}
