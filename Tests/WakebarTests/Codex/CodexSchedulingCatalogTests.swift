import XCTest
@testable import WakebarCore

final class CodexSchedulingCatalogTests: XCTestCase {
    func testHostedTaskCanRunWithoutThisMacButCannotUseItsLocalFiles() throws {
        let capability = try XCTUnwrap(
            CodexSchedulingCatalog.capabilities().first { $0.route == .chatGPTWebTask }
        )

        XCTAssertTrue(capability.hostRequirement.canRunWhileThisMacIsOff)
        XCTAssertFalse(capability.canAccessLocalProjectFiles)
        XCTAssertEqual(capability.scheduleManager, .chatGPT)
        XCTAssertFalse(capability.usageWindowEffect.isVerified)
    }

    func testDesktopProjectTaskRequiresThisMacAndTheDesktopApp() throws {
        let capability = try XCTUnwrap(
            CodexSchedulingCatalog.capabilities().first { $0.route == .desktopProjectTask }
        )

        XCTAssertFalse(capability.hostRequirement.canRunWhileThisMacIsOff)
        XCTAssertEqual(capability.hostRequirement, .thisMac(appMustBeRunning: true))
        XCTAssertTrue(capability.canAccessLocalProjectFiles)
    }

    func testLocalCLIRequiresAnExternalScheduler() throws {
        let capability = try XCTUnwrap(
            CodexSchedulingCatalog.capabilities(cliAvailability: .available(version: "1.0"))
                .first { $0.route == .localCLI }
        )

        XCTAssertEqual(capability.scheduleManager, .external)
        XCTAssertEqual(capability.status.label, "Experimental")
        XCTAssertFalse(capability.hostRequirement.canRunWhileThisMacIsOff)
    }

    func testAlwaysOnRunnerDoesNotPromiseLocalProjectAccessOrUsageReset() throws {
        let capability = try XCTUnwrap(
            CodexSchedulingCatalog.capabilities().first { $0.route == .alwaysOnRunner }
        )

        XCTAssertTrue(capability.hostRequirement.canRunWhileThisMacIsOff)
        XCTAssertFalse(capability.canAccessLocalProjectFiles)
        XCTAssertFalse(capability.usageWindowEffect.isVerified)
    }
}
