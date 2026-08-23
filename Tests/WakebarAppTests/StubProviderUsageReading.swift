import Foundation
import WakebarCore
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

actor StubProviderUsageReading: ProviderUsageReading {
    private var readings: [[UsageWindow]]

    init(readings: [[UsageWindow]]) {
        self.readings = readings
    }

    func currentWindows(now: Date) async throws -> [UsageWindow] {
        guard readings.count > 1 else { return readings.first ?? [] }
        return readings.removeFirst()
    }
}
