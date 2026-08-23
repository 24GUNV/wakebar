import Foundation
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

struct ImmediateUsageWindowPollingSleeper: UsageWindowPollingSleeping {
    func sleep(for duration: Duration) async throws {}
}
