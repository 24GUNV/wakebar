import Foundation

protocol UsageWindowPollingSleeping: Sendable {
    func sleep(for duration: Duration) async throws
}
