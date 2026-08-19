import XCTest
@testable import WakebarCore

final class CodexCLIPreviewPlanTests: XCTestCase {
    func testDefaultPlanUsesMinimalEphemeralReadOnlyRun() throws {
        let plan = try CodexCLIPreviewPlan()

        XCTAssertEqual(plan.executable, "codex")
        XCTAssertEqual(plan.prompt, "hi")
        XCTAssertEqual(plan.arguments, [
            "exec",
            "--ephemeral",
            "--json",
            "--sandbox",
            "read-only",
            "hi",
        ])
        XCTAssertTrue(plan.resultMeaning.contains("does not confirm"))
    }

    func testPromptIsPassedAsOneArgumentInsteadOfShellSource() throws {
        let prompt = "hi; touch /tmp/should-not-run"
        let plan = try CodexCLIPreviewPlan(prompt: prompt)

        XCTAssertEqual(plan.arguments.last, prompt)
        XCTAssertEqual(plan.arguments.count, 6)
    }

    func testEmptyPromptIsRejected() {
        XCTAssertThrowsError(
            try CodexCLIPreviewPlan(prompt: "  \n ")
        ) { error in
            XCTAssertEqual(error as? CodexCLIPreviewError, .emptyPrompt)
        }
    }
}
