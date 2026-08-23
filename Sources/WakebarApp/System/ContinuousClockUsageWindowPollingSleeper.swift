import Foundation

struct ContinuousClockUsageWindowPollingSleeper: UsageWindowPollingSleeping {
    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}
