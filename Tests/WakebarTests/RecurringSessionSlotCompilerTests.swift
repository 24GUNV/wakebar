import XCTest
@testable import WakebarCore

final class RecurringSessionSlotCompilerTests: XCTestCase {
    func testCompilesInitialAndFiveHourRefreshSlots() {
        var schedule = WakeSchedule.default
        schedule.hour = 7
        schedule.minute = 0
        schedule.sessionLeadMinutes = 10
        schedule.repeatEveryFiveHours = true
        schedule.repeatUntilHour = 19

        let slots = RecurringSessionSlotCompiler().slots(for: schedule)

        XCTAssertEqual(slots.map(\.hour), [6, 11, 16])
        XCTAssertEqual(slots.map(\.minute), [50, 50, 50])
        XCTAssertEqual(slots.map(\.phase), [.initial, .refresh(index: 1), .refresh(index: 2)])
    }

    func testPreWakeSlotMovesToPreviousWeekdayWhenCrossingMidnight() {
        var schedule = WakeSchedule.default
        schedule.hour = 0
        schedule.minute = 5
        schedule.sessionLeadMinutes = 10
        schedule.selectedWeekdays = [.monday]

        let slot = RecurringSessionSlotCompiler().slots(for: schedule).first

        XCTAssertEqual(slot?.hour, 23)
        XCTAssertEqual(slot?.minute, 55)
        XCTAssertEqual(slot?.weekdays, [.sunday])
    }
}
