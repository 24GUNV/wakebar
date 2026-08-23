import Foundation
import WakebarCore

protocol ProviderUsageReading: Sendable {
    func currentWindows(now: Date) async throws -> [UsageWindow]
}
