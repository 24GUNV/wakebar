import Foundation
import Testing
@testable import WakebarCore

struct WakeScheduleTests {
    @Test
    func legacyScheduleDecodesWithNewDefaults() throws {
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

        #expect(schedule.selectedWeekdays == Weekday.workweek)
        #expect(schedule.sessionLeadMinutes == 10)
        #expect(schedule.alarmOnIPhone)
        #expect(!schedule.repeatEveryFiveHours)
        #expect(schedule.followsSystemTimeZone)
    }

    @Test
    func currentScheduleRoundTrips() throws {
        var schedule = WakeSchedule.default
        schedule.selectedWeekdays = [.monday, .wednesday, .friday]
        schedule.sessionLeadMinutes = 15
        schedule.repeatEveryFiveHours = true

        let data = try JSONEncoder().encode(schedule)
        let decoded = try JSONDecoder().decode(WakeSchedule.self, from: data)

        #expect(decoded == schedule)
    }

    @Test
    func scheduleRequiresADayAndProvider() {
        var schedule = WakeSchedule.default
        schedule.selectedWeekdays = []
        #expect(!schedule.isValid)

        schedule.selectedWeekdays = Weekday.workweek
        schedule.includeClaude = false
        schedule.includeCodex = false
        #expect(!schedule.isValid)
    }
}
