#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

actor StubCodexStartRequester: CodexStartRequesting {
    private(set) var prompts: [String] = []

    func requestStart(prompt: String) async throws {
        prompts.append(prompt)
    }
}
