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
}
