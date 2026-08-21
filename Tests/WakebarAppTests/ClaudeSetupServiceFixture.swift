import Foundation
@testable import Wakebar

@MainActor
struct ClaudeSetupServiceFixture {
    let root: URL
    let executableURL: URL

    var launcherDirectory: URL {
        root.appending(path: "Launchers", directoryHint: .isDirectory)
    }

    func service(
        behaviors: [String: TestCLICommandRunner.Behavior],
        opener: TestTerminalOpener = TestTerminalOpener()
    ) -> ClaudeCLISetupService {
        ClaudeCLISetupService(
            runner: TestCLICommandRunner(behaviors: behaviors),
            terminalOpener: opener,
            launcherDirectory: launcherDirectory,
            executableCandidatesOverride: [executableURL]
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
