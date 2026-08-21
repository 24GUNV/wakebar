import XCTest
@testable import WakebarCore

final class ClaudeCLIVersionTests: XCTestCase {
    func testParsesClaudeCodeVersionOutput() {
        XCTAssertEqual(
            ClaudeCLIVersion(output: "2.1.227 (Claude Code)\n"),
            ClaudeCLIVersion(major: 2, minor: 1, patch: 227)
        )
    }

    func testRejectsMalformedOutput() {
        XCTAssertNil(ClaudeCLIVersion(output: "Claude Code current"))
    }

    func testComparesEachVersionComponent() {
        let minimum = ClaudeRoutineCLISetupPlan.minimumVersion

        XCTAssertLessThan(ClaudeCLIVersion(major: 2, minor: 1, patch: 226), minimum)
        XCTAssertEqual(ClaudeCLIVersion(major: 2, minor: 1, patch: 227), minimum)
        XCTAssertGreaterThan(ClaudeCLIVersion(major: 2, minor: 2, patch: 0), minimum)
    }
}
