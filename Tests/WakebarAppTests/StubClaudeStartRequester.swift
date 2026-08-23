import WakebarCore
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

actor StubClaudeStartRequester: ClaudeStartRequesting {
    private(set) var requestCount = 0

    func requestStart(for schedule: WakeSchedule) async throws {
        requestCount += 1
    }
}
