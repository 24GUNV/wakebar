import Foundation
import XCTest
@testable import Wakebar

final class FoundationCLICommandRunnerTests: XCTestCase {
    func testCapturesOutputWithoutPipeBackpressure() async throws {
        let runner = FoundationCLICommandRunner()

        let result = try await runner.run(
            executableURL: URL(filePath: "/usr/bin/seq"),
            arguments: ["1", "10000"],
            timeout: .seconds(3)
        )

        XCTAssertEqual(result.status, 0)
        XCTAssertTrue(result.output.hasPrefix("1\n2\n"))
        XCTAssertTrue(result.output.hasSuffix("10000\n"))
    }

    func testTerminatesProcessAtTimeout() async {
        let runner = FoundationCLICommandRunner()

        do {
            _ = try await runner.run(
                executableURL: URL(filePath: "/bin/sleep"),
                arguments: ["5"],
                timeout: .milliseconds(50)
            )
            XCTFail("Expected timeout")
        } catch {
            XCTAssertEqual(error as? CLICommandRunnerError, .timedOut)
        }
    }
}
