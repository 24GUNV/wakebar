import XCTest
@testable import WakebarCore

final class ClaudeRoutineTerminalScriptBuilderTests: XCTestCase {
    func testSetupScriptKeepsCommandAsOneShellArgument() {
        let command = "/schedule create Wakebar; touch /tmp/should-not-run"

        let script = ClaudeRoutineTerminalScriptBuilder().script(
            executablePath: "/Applications/Claude's Tools/claude",
            setupCommand: command
        )

        XCTAssertTrue(script.contains("'/Applications/Claude'\\''s Tools/claude'"))
        XCTAssertTrue(script.contains("--safe-mode --no-chrome --ax-screen-reader"))
        XCTAssertTrue(script.contains("'/schedule create Wakebar; touch /tmp/should-not-run'"))
        XCTAssertFalse(script.contains("claude; touch"))
    }

    func testUpdateScriptUsesFixedUpdateArgument() {
        let script = ClaudeRoutineTerminalScriptBuilder().updateScript(
            executablePath: "/Users/example/.local/bin/claude"
        )

        XCTAssertTrue(script.contains("'/Users/example/.local/bin/claude' update"))
    }

    func testLoginScriptUsesClaudeAIAccountFlow() {
        let script = ClaudeRoutineTerminalScriptBuilder().loginScript(
            executablePath: "/Users/example/.local/bin/claude"
        )

        XCTAssertTrue(script.contains("auth login --claudeai"))
        XCTAssertTrue(script.contains("unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN"))
    }
}
