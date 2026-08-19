import Foundation
import XCTest
@testable import WakebarCore

final class WakeScheduleTests: XCTestCase {
    func testDefaultScheduleIsAnUnpublishedDraft() {
        XCTAssertFalse(WakeSchedule.default.isEnabled)
    }

    func testLegacyScheduleDecodesWithNewDefaults() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "isEnabled": true,
          "hour": 6,
          "minute": 30,
          "weekdaysOnly": true,
          "includeClaude": true,
          "includeCodex": false,
          "claudeBackend": "providerCloud",
          "codexBackend": "thisMac",
          "timeZoneIdentifier": "UTC"
        }
        """

        let schedule = try JSONDecoder().decode(WakeSchedule.self, from: Data(json.utf8))

        XCTAssertEqual(schedule.selectedWeekdays, Weekday.workweek)
        XCTAssertEqual(schedule.sessionLeadMinutes, 10)
        XCTAssertTrue(schedule.alarmOnIPhone)
        XCTAssertFalse(schedule.repeatEveryFiveHours)
        XCTAssertTrue(schedule.followsSystemTimeZone)
    }

    func testCurrentScheduleRoundTrips() throws {
        var schedule = WakeSchedule.default
        schedule.selectedWeekdays = [.monday, .wednesday, .friday]
        schedule.sessionLeadMinutes = 15
        schedule.repeatEveryFiveHours = true

        let data = try JSONEncoder().encode(schedule)
        let decoded = try JSONDecoder().decode(WakeSchedule.self, from: data)

        XCTAssertEqual(decoded, schedule)
    }

    func testScheduleRequiresADayAndProvider() {
        var schedule = WakeSchedule.default
        schedule.selectedWeekdays = []
        XCTAssertFalse(schedule.isValid)

        schedule.selectedWeekdays = Weekday.workweek
        schedule.includeClaude = false
        schedule.includeCodex = false
        XCTAssertFalse(schedule.isValid)
    }
}
