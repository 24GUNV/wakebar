import Foundation
import WakebarCore
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

actor StubProviderUsageReading: ProviderUsageReading {
    private let error: (any Error)?
    private var readings: [[UsageWindow]]

    init(readings: [[UsageWindow]], error: (any Error)? = nil) {
        self.error = error
        self.readings = readings
    }

    func currentWindows(now: Date) async throws -> [UsageWindow] {
        if let error { throw error }
        guard readings.count > 1 else { return readings.first ?? [] }
        return readings.removeFirst()
    }
}
