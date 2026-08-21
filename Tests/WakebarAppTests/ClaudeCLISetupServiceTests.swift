import Foundation
import XCTest
@testable import Wakebar

@MainActor
final class ClaudeCLISetupServiceTests: XCTestCase {
    func testSubscriptionAuthenticationIsReady() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let service = fixture.service(
            behaviors: standardBehaviors(authMethod: "claude.ai")
        )

        let state = await service.probe()

        XCTAssertEqual(state, .ready(version: "2.1.237"))
    }

    func testConsoleAuthenticationIsRejected() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let service = fixture.service(
            behaviors: standardBehaviors(authMethod: "api_key")
        )

        let state = await service.probe()

        XCTAssertEqual(
            state,
            .unsupportedAuthentication(version: "2.1.237", method: "api_key")
        )
    }

    func testMalformedAuthenticationResponseFailsClosed() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let service = fixture.service(behaviors: [
            "--version": .result(CLICommandResult(status: 0, output: "2.1.237 (Claude Code)")),
            "auth status --json": .result(CLICommandResult(status: 0, output: "not json")),
        ])

        let state = await service.probe()

        XCTAssertEqual(state, .failed("Claude Code did not start correctly."))
    }

    func testProbeTimeoutReturnsFailureInsteadOfHanging() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let service = fixture.service(behaviors: [
            "--version": .error(.timedOut),
        ])

        let state = await service.probe()

        XCTAssertEqual(state, .failed("Claude Code did not respond."))
    }

    func testEmptyCandidateListReportsNotFound() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let service = ClaudeCLISetupService(
            runner: TestCLICommandRunner(behaviors: [:]),
            terminalOpener: TestTerminalOpener(),
            launcherDirectory: fixture.launcherDirectory,
            executableCandidatesOverride: []
        )

        let state = await service.probe()

        XCTAssertEqual(state, .notFound)
    }

    func testLauncherIsPrivateAndOpenFailureIsReported() async throws {
        let fixture = try makeFixture()
        defer { fixture.remove() }
        let opener = TestTerminalOpener(shouldOpen: false)
        let service = fixture.service(
            behaviors: standardBehaviors(authMethod: "claude.ai"),
            opener: opener
        )

        do {
            try await service.launchRoutineSetup(for: .default)
            XCTFail("Expected Terminal open failure")
        } catch {
            XCTAssertEqual(error as? ClaudeCLISetupError, .couldNotOpenTerminal)
        }

        let launcherURL = try XCTUnwrap(opener.openedURLs.first)
        let attributes = try FileManager.default.attributesOfItem(atPath: launcherURL.path)
        XCTAssertEqual(attributes[.posixPermissions] as? NSNumber, 0o700)
        let contents = try String(contentsOf: launcherURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("unset ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN"))
        XCTAssertTrue(contents.contains("auth status --json"))
    }

    private func standardBehaviors(authMethod: String) -> [String: TestCLICommandRunner.Behavior] {
        [
            "--version": .result(CLICommandResult(status: 0, output: "2.1.237 (Claude Code)")),
            "auth status --json": .result(
                CLICommandResult(
                    status: 0,
                    output: "{\"loggedIn\":true,\"authMethod\":\"\(authMethod)\"}"
                )
            ),
        ]
    }

    private func makeFixture() throws -> ClaudeSetupServiceFixture {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "wakebar-setup-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let executableURL = root.appending(path: "claude")
        XCTAssertTrue(FileManager.default.createFile(atPath: executableURL.path, contents: Data()))
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: executableURL.path
        )
        return ClaudeSetupServiceFixture(root: root, executableURL: executableURL)
    }
}
