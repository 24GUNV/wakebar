import Foundation
import XCTest
@testable import WakebarCore

final class ScheduleStoreTests: XCTestCase {
    func testScheduleSurvivesRelaunchWhenStorePathContainsSpaces() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Wakebar Schedule \(UUID())", directoryHint: .isDirectory)
        let fileURL = directory.appending(path: "schedule.json")
        let schedule = WakeSchedule.default

        try await ScheduleStore(fileURL: fileURL).save(schedule)
        let reloaded = try await ScheduleStore(fileURL: fileURL).load()

        XCTAssertEqual(reloaded, schedule)
    }
}
