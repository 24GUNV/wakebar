import XCTest
@testable import WakebarApp

@MainActor
final class CodexSetupModelTests: XCTestCase {
    func testTaskInstructionsKeepRecurringTaskEnabled() {
        let instructions = CodexSetupModel().instructions(for: .default)

        XCTAssertTrue(instructions.contains("reply only with “hi”"))
        XCTAssertTrue(instructions.contains("Keep the recurring task enabled after every run"))
        XCTAssertTrue(instructions.contains("do not pause, disable, delete, or modify it"))
    }
}
