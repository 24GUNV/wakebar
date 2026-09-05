import Foundation
import XCTest
@testable import WakebarCore

final class CodexWakePlannerTests: XCTestCase {
    private let week: TimeInterval = 7 * 24 * 60 * 60
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    // MARK: - Every reset

    func testContinuousFiresAtOnceWhenTheWeeklyCapIsUnstarted() throws {
        let now = try date(hour: 9)
        let decision = planner().decide(
            schedule: schedule(cadence: .continuous),
            windows: [weekly(unstartedAt: now)],
            now: now,
            lastHandledAt: nil
        )

        XCTAssertTrue(decision.firesNow)
        XCTAssertEqual(decision.dueAt, now)
        XCTAssertEqual(decision.nextCheck, now.addingTimeInterval(CodexWakePlanner.settleInterval))
    }

    func testContinuousWaitsForTheResetWhenTheWeekIsRunning() throws {
        let now = try date(hour: 9)
        let reset = now.addingTimeInterval(2 * 24 * 60 * 60)
        let decision = planner().decide(
            schedule: schedule(cadence: .continuous),
            windows: [weekly(resetsAt: reset, used: 0.4, observedAt: now)],
            now: now,
            lastHandledAt: nil
        )

        XCTAssertFalse(decision.firesNow)
        XCTAssertEqual(decision.nextCheck, reset.addingTimeInterval(ChainedSessionPlanner.resetBuffer))
    }

    /// A reading taken seconds after a wake can still show the placeholder,
    /// and firing again on it would double every wake.
    func testContinuousDoesNotRefireInsideTheSettleInterval() throws {
        let now = try date(hour: 9)
        let decision = planner().decide(
            schedule: schedule(cadence: .continuous),
            windows: [weekly(unstartedAt: now)],
            now: now,
            lastHandledAt: now.addingTimeInterval(-60)
        )

        XCTAssertFalse(decision.firesNow)
        XCTAssertEqual(
            decision.nextCheck,
            now.addingTimeInterval(CodexWakePlanner.settleInterval - 60)
        )
    }

    func testSessionWindowGovernsWhenThePlanReportsOne() throws {
        let now = try date(hour: 9)
        let sessionReset = now.addingTimeInterval(60 * 60)
        let decision = planner().decide(
            schedule: schedule(cadence: .continuous),
            windows: [
                weekly(resetsAt: now.addingTimeInterval(3 * 24 * 60 * 60), used: 0.5, observedAt: now),
                UsageWindow(
                    provider: .codex,
                    duration: 5 * 60 * 60,
                    resetsAt: sessionReset,
                    usedFraction: 0.2,
                    observedAt: now,
                    confidence: .reported
                ),
            ],
            now: now,
            lastHandledAt: nil
        )

        XCTAssertFalse(decision.firesNow)
        XCTAssertEqual(decision.nextCheck, sessionReset.addingTimeInterval(ChainedSessionPlanner.resetBuffer))
    }

    // MARK: - Before each wake

    func testScheduleFiresOnceAtTheSlotAndThenWaitsForTheNext() throws {
        // Wake 07:00 with a 10-minute lead: the slot is 06:50.
        let slot = try date(hour: 6, minute: 50)
        let now = slot.addingTimeInterval(30)
        let first = planner().decide(
            schedule: schedule(cadence: .schedule),
            windows: [weekly(unstartedAt: now)],
            now: now,
            lastHandledAt: nil
        )

        XCTAssertTrue(first.firesNow)
        XCTAssertEqual(first.dueAt, slot)
        XCTAssertEqual(first.nextCheck, slot.addingTimeInterval(24 * 60 * 60))

        let second = planner().decide(
            schedule: schedule(cadence: .schedule),
            windows: [weekly(unstartedAt: now)],
            now: now.addingTimeInterval(60),
            lastHandledAt: first.dueAt
        )
        XCTAssertFalse(second.firesNow)
        XCTAssertNil(second.dueAt)
    }

    /// The Mac slept through the slot. The wake is still worth sending when
    /// it comes back, hours later, because the window is still unopened.
    func testScheduleCatchesUpAMissedSlotWhileTheWindowIsUnopened() throws {
        let slot = try date(hour: 6, minute: 50)
        let now = try date(hour: 15)
        let decision = planner().decide(
            schedule: schedule(cadence: .schedule),
            windows: [weekly(unstartedAt: now)],
            now: now,
            lastHandledAt: slot.addingTimeInterval(-24 * 60 * 60)
        )

        XCTAssertTrue(decision.firesNow)
        XCTAssertEqual(decision.dueAt, slot)
    }

    /// The user opened the window themselves before the Mac woke. The slot is
    /// settled without a request so it does not stay pending all day.
    func testScheduleSettlesAMissedSlotWithoutFiringWhenTheWindowIsOpen() throws {
        let slot = try date(hour: 6, minute: 50)
        let now = try date(hour: 15)
        let decision = planner().decide(
            schedule: schedule(cadence: .schedule),
            windows: [weekly(resetsAt: now.addingTimeInterval(week - 3600), used: 0.01, observedAt: now)],
            now: now,
            lastHandledAt: nil
        )

        XCTAssertFalse(decision.firesNow)
        XCTAssertEqual(decision.dueAt, slot)
    }

    func testNoReadingFiresOnTrustSoABadCredentialFailsLoudly() throws {
        let now = try date(hour: 9)
        let decision = planner().decide(
            schedule: schedule(cadence: .continuous),
            windows: [],
            now: now,
            lastHandledAt: nil
        )

        XCTAssertTrue(decision.firesNow)
    }

    func testDisabledOrCodexFreeSchedulesDoNothing() throws {
        let now = try date(hour: 9)
        var off = schedule(cadence: .continuous)
        off.isEnabled = false
        var noCodex = schedule(cadence: .continuous)
        noCodex.includeCodex = false

        XCTAssertEqual(
            planner().decide(schedule: off, windows: [], now: now, lastHandledAt: nil),
            .nothing
        )
        XCTAssertEqual(
            planner().decide(schedule: noCodex, windows: [], now: now, lastHandledAt: nil),
            .nothing
        )
    }

    // MARK: - Helpers

    private func planner() -> CodexWakePlanner {
        CodexWakePlanner(calculator: ScheduleCalculator(calendar: calendar))
    }

    private func schedule(cadence: SessionCadence) -> WakeSchedule {
        WakeSchedule(
            id: UUID(),
            isEnabled: true,
            hour: 7,
            minute: 0,
            selectedWeekdays: Set(Weekday.allCases),
            sessionLeadMinutes: 10,
            repeatEveryFiveHours: false,
            repeatUntilHour: 19,
            cadence: cadence,
            includeClaude: true,
            includeCodex: true,
            claudeBackend: .providerCloud,
            codexBackend: .thisMac,
            followsSystemTimeZone: false,
            timeZoneIdentifier: "UTC"
        )
    }

    private func date(hour: Int, minute: Int = 0) throws -> Date {
        try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: hour, minute: minute))
        )
    }

    private func weekly(unstartedAt now: Date) -> UsageWindow {
        weekly(resetsAt: now.addingTimeInterval(week), used: 0, observedAt: now)
    }

    private func weekly(resetsAt: Date, used: Double, observedAt: Date) -> UsageWindow {
        UsageWindow(
            provider: .codex,
            duration: week,
            resetsAt: resetsAt,
            usedFraction: used,
            observedAt: observedAt,
            confidence: .reported
        )
    }
}
