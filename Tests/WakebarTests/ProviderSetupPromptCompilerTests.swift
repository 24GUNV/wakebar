import XCTest
@testable import WakebarCore

final class ProviderSetupPromptCompilerTests: XCTestCase {
    func testClaudeDetailsIncludeEveryPlannedStartAndSafetyBoundary() {
        var schedule = WakeSchedule.default
        schedule.repeatEveryFiveHours = true
        schedule.repeatUntilHour = 19
        schedule.followsSystemTimeZone = false
        schedule.timeZoneIdentifier = "Asia/Bangkok"

        let command = ProviderSetupPromptCompiler().claudeRoutineInstructions(for: schedule)

        XCTAssertTrue(command.hasPrefix("Name: Wakebar"))
        XCTAssertTrue(command.contains("06:50"))
        XCTAssertTrue(command.contains("11:50"))
        XCTAssertTrue(command.contains("16:50"))
        XCTAssertTrue(command.contains("Asia/Bangkok"))
        XCTAssertTrue(command.contains("Prompt: Reply with exactly \"yes\"."))
        XCTAssertTrue(command.contains("Repositories: None"))
        XCTAssertTrue(command.contains("Connectors: None"))
    }

    func testChatGPTPromptLabelsExperimentalTaskPrecisely() {
        var schedule = WakeSchedule.default
        schedule.followsSystemTimeZone = false
        schedule.timeZoneIdentifier = "America/New_York"

        let prompt = ProviderSetupPromptCompiler().chatGPTTaskPrompt(for: schedule)

        XCTAssertTrue(prompt.contains("ChatGPT Scheduled task"))
        XCTAssertTrue(prompt.contains("06:50"))
        XCTAssertTrue(prompt.contains("America/New_York"))
        XCTAssertTrue(prompt.contains("exactly \"hi\""))
        XCTAssertTrue(prompt.contains("confirmation before saving"))
    }

    func testClaudeCLICommandReconcilesOwnedRoutinesWithoutDuplicates() {
        var schedule = WakeSchedule.default
        schedule.repeatEveryFiveHours = true
        schedule.repeatUntilHour = 19
        schedule.followsSystemTimeZone = false
        schedule.timeZoneIdentifier = "Asia/Bangkok"

        let command = ProviderSetupPromptCompiler().claudeRoutineCLICommand(for: schedule)

        XCTAssertTrue(command.hasPrefix("/schedule"))
        XCTAssertTrue(command.contains("First list existing matching Routines"))
        XCTAssertTrue(command.contains("create missing ones"))
        XCTAssertTrue(command.contains("disable obsolete matching Routines"))
        XCTAssertTrue(command.contains("06:50"))
        XCTAssertTrue(command.contains("11:50"))
        XCTAssertTrue(command.contains("16:50"))
        XCTAssertTrue(command.contains("Reply with exactly \"yes\""))
        XCTAssertTrue(command.contains("no repositories"))
        XCTAssertTrue(command.contains("no connectors"))
        XCTAssertTrue(command.contains("ask for one confirmation"))
        XCTAssertTrue(command.contains(schedule.id.uuidString.prefix(8).uppercased()))
    }
}
