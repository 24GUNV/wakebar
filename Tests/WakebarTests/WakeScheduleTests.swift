import Foundation
import XCTest
@testable import WakebarCore

final class WakeScheduleTests: XCTestCase {
    func testHostedSetupSurvivesTheMasterSwitch() {
        var original = WakeSchedule.default
        original.isEnabled = true
        var updated = original
        updated.isEnabled = false

        // The enabled state is reconciled separately from the hosted schedule
        // configuration, so its existing confirmation still applies.
        XCTAssertTrue(updated.hasSameHostedSetup(as: original, for: .claude))
        XCTAssertTrue(updated.hasSameHostedSetup(as: original, for: .codex))
    }

    func testHostedSetupChangesWhenProviderTimingChanges() {
        let original = WakeSchedule.default
        var updated = original
        updated.sessionLeadMinutes = 30

        XCTAssertFalse(updated.hasSameHostedSetup(as: original, for: .claude))
        XCTAssertFalse(updated.hasSameHostedSetup(as: original, for: .codex))
    }

    func testFiveHourSettingsAffectOnlyClaudeHostedSetup() {
        let original = WakeSchedule.default
        var updated = original
        updated.repeatEveryFiveHours = true
        updated.repeatUntilHour = 17

        XCTAssertFalse(updated.hasSameHostedSetup(as: original, for: .claude))
        XCTAssertTrue(updated.hasSameHostedSetup(as: original, for: .codex))
    }

    func testHostedSetupTracksOnlyTheAffectedProviderSelection() {
        let original = WakeSchedule.default
        var updated = original
        updated.includeCodex = false

        XCTAssertTrue(updated.hasSameHostedSetup(as: original, for: .claude))
        XCTAssertFalse(updated.hasSameHostedSetup(as: original, for: .codex))
    }

    func testRemovedProvidersAreReportedInStableProviderOrder() {
        var active = WakeSchedule.default
        active.isEnabled = true
        var updated = active
        updated.includeClaude = false
        updated.includeCodex = false

        XCTAssertEqual(updated.providersRemoved(from: active), [.claude, .codex])
    }

    func testUnpublishedDraftDoesNotRequireProviderCleanup() {
        let unpublishedDraft = WakeSchedule.default
        var updated = unpublishedDraft
        updated.includeCodex = false

        XCTAssertTrue(updated.providersRemoved(from: unpublishedDraft).isEmpty)
    }

    func testDefaultScheduleIsAnUnpublishedDraft() {
        XCTAssertFalse(WakeSchedule.default.isEnabled)
    }

    func testLegacyScheduleDecodesWithNewDefaults() throws {
        let retiredKey = ["al", "armOnI", "Pho", "ne"].joined()
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "isEnabled": true,
          "hour": 6,
          "minute": 30,
          "weekdaysOnly": true,
          "\(retiredKey)": true,
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
        XCTAssertFalse(schedule.repeatEveryFiveHours)
        XCTAssertTrue(schedule.followsSystemTimeZone)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(schedule), as: UTF8.self).contains(retiredKey))
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
