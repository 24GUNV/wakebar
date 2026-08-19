import Foundation
import WakebarCore

@main
enum WakebarVerification {
    static func main() async throws {
        try verifyActiveWakePlanning()
        try await verifyExecutionLedger()
        try verifyProviderSafety()
        print("Wakebar core verification passed")
    }

    private static func verifyActiveWakePlanning() throws {
        var calendar = Calendar(identifier: .gregorian)
        guard let utc = TimeZone(secondsFromGMT: 0) else {
            throw VerificationError.missingUTC
        }
        calendar.timeZone = utc

        var schedule = WakeSchedule.default
        schedule.hour = 7
        schedule.minute = 0
        schedule.selectedWeekdays = Weekday.workweek
        schedule.sessionLeadMinutes = 10
        schedule.repeatEveryFiveHours = true
        schedule.repeatUntilHour = 19
        schedule.includeClaude = true
        schedule.includeCodex = false
        schedule.followsSystemTimeZone = false
        schedule.timeZoneIdentifier = "UTC"

        let planner = SchedulePlanner(
            calculator: ScheduleCalculator(calendar: calendar),
            calendar: calendar
        )
        guard let afterWake = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 20, hour: 8)
        ) else {
            throw VerificationError.invalidFixtureDate
        }

        let events = planner.nextEvents(after: afterWake, for: schedule)
        let eventHours = events.map { calendar.component(.hour, from: $0.date) }
        guard eventHours == [11, 16] else {
            throw VerificationError.unexpectedRefreshes(eventHours)
        }
    }

    private static func verifyExecutionLedger() async throws {
        let ledgerURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "ledger.json")
        let ledger = ExecutionLedger(fileURL: ledgerURL)

        guard try await ledger.claim(eventID: "smoke-event") else {
            throw VerificationError.duplicateFirstClaim
        }
        try await ledger.markDeliveryUnknown(eventID: "smoke-event")
        guard try await ledger.record(for: "smoke-event")?.state == .deliveryUnknown else {
            throw VerificationError.ledgerStateMismatch
        }
        guard try await !ledger.resetFailedBeforeSendForRetry(eventID: "smoke-event") else {
            throw VerificationError.unsafeRetryAllowed
        }
    }

    private static func verifyProviderSafety() throws {
        guard let maliciousURL = URL(
            string: "https://example.com/v1/claude_code/routines/trig_test/fire"
        ) else {
            throw VerificationError.invalidFixtureURL
        }

        do {
            _ = try ClaudeRoutineAPIConfiguration(
                fireURL: maliciousURL,
                credential: ClaudeRoutineCredentialReference(id: "smoke")
            )
            throw VerificationError.unsafeEndpointAccepted
        } catch ClaudeRoutineError.invalidEndpoint {
            return
        }
    }
}
