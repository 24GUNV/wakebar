import Foundation
import WakebarCore

actor ClaudeCLISetupService {
    private let runner: any CLICommandRunning
    private let terminalOpener: any TerminalOpening
    private let launcherDirectory: URL
    private let executableCandidatesOverride: [URL]?
    private var executableURL: URL?

    init(
        runner: any CLICommandRunning = FoundationCLICommandRunner(),
        terminalOpener: any TerminalOpening = WorkspaceTerminalOpener(),
        launcherDirectory: URL = URL.applicationSupportDirectory
            .appending(path: "Wakebar", directoryHint: .isDirectory)
            .appending(path: "Launchers", directoryHint: .isDirectory),
        executableCandidatesOverride: [URL]? = nil
    ) {
        self.runner = runner
        self.terminalOpener = terminalOpener
        self.launcherDirectory = launcherDirectory
        self.executableCandidatesOverride = executableCandidatesOverride
    }

    func probe() async -> ClaudeCLISetupState {
        guard let executableURL = locateExecutable() else {
            self.executableURL = nil
            return .notFound
        }

        do {
            let output = try await versionOutput(from: executableURL)
            guard let version = ClaudeCLIVersion(output: output) else {
                return .failed(ClaudeCLISetupError.invalidVersion.localizedDescription)
            }

            self.executableURL = executableURL
            let required = ClaudeRoutineCLISetupPlan.minimumVersion
            if version < required {
                return .updateRequired(
                    installed: version.description,
                    required: required.description
                )
            }
            let authentication = try await authenticationStatus(from: executableURL)
            guard authentication.loggedIn else {
                return .signInRequired(version: version.description)
            }
            guard authentication.method == "claude.ai" else {
                return .unsupportedAuthentication(
                    version: version.description,
                    method: authentication.method
                )
            }
            return .ready(version: version.description)
        } catch CLICommandRunnerError.timedOut {
            return .failed(ClaudeCLISetupError.processTimedOut.localizedDescription)
        } catch {
            return .failed(ClaudeCLISetupError.processFailed.localizedDescription)
        }
    }

    func launchRoutineSetup(for schedule: WakeSchedule) async throws {
        let executableURL = try await currentSupportedExecutable()
        let plan = ClaudeRoutineCLISetupPlan(schedule: schedule)
        let script = ClaudeRoutineTerminalScriptBuilder().script(
            executablePath: executableURL.path,
            setupCommand: plan.command
        )
        let launcherURL = try writeLauncher(named: "claude-routine-setup", contents: script)
        try await openInTerminal(launcherURL)
    }

    func launchUpdate() async throws {
        guard let executableURL = executableURL ?? locateExecutable() else {
            throw ClaudeCLISetupError.executableNotFound
        }
        let script = ClaudeRoutineTerminalScriptBuilder().updateScript(
            executablePath: executableURL.path
        )
        let launcherURL = try writeLauncher(named: "claude-code-update", contents: script)
        try await openInTerminal(launcherURL)
    }

    func launchLogin() async throws {
        guard let executableURL = executableURL ?? locateExecutable() else {
            throw ClaudeCLISetupError.executableNotFound
        }
        let script = ClaudeRoutineTerminalScriptBuilder().loginScript(
            executablePath: executableURL.path
        )
        let launcherURL = try writeLauncher(named: "claude-code-login", contents: script)
        try await openInTerminal(launcherURL)
    }

    private func currentSupportedExecutable() async throws -> URL {
        guard let executableURL = executableURL ?? locateExecutable() else {
            throw ClaudeCLISetupError.executableNotFound
        }
        let output = try await versionOutput(from: executableURL)
        guard let version = ClaudeCLIVersion(output: output) else {
            throw ClaudeCLISetupError.invalidVersion
        }
        guard version >= ClaudeRoutineCLISetupPlan.minimumVersion else {
            throw ClaudeCLISetupError.updateRequired
        }
        self.executableURL = executableURL
        return executableURL
    }

    private func locateExecutable() -> URL? {
        var candidates: [URL]
        if let executableCandidatesOverride {
            candidates = executableCandidatesOverride
        } else {
            candidates = [
                URL.homeDirectory.appending(path: ".local/bin/claude"),
                URL(filePath: "/opt/homebrew/bin/claude"),
                URL(filePath: "/usr/local/bin/claude"),
            ]

            if let path = ProcessInfo.processInfo.environment["PATH"] {
                candidates.append(contentsOf: path.split(separator: ":").map { directory in
                    URL(filePath: String(directory)).appending(path: "claude")
                })
            }
        }

        var visited = Set<String>()
        return candidates.first { candidate in
            let path = candidate.standardizedFileURL.path
            guard visited.insert(path).inserted else { return false }
            return FileManager.default.isExecutableFile(atPath: path)
        }
    }

    private func versionOutput(from executableURL: URL) async throws -> String {
        let result = try await runner.run(
            executableURL: executableURL,
            arguments: ["--version"],
            timeout: .seconds(3)
        )
        guard result.status == 0 else {
            throw ClaudeCLISetupError.processFailed
        }
        return result.output
    }

    private func authenticationStatus(from executableURL: URL) async throws -> (loggedIn: Bool, method: String) {
        let result = try await runner.run(
            executableURL: executableURL,
            arguments: ["auth", "status", "--json"],
            timeout: .seconds(3)
        )
        guard let data = result.output.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw ClaudeCLISetupError.processFailed }

        let loggedIn = object["loggedIn"] as? Bool == true
        let method = object["authMethod"] as? String ?? "unknown"
        if result.status != 0, loggedIn {
            throw ClaudeCLISetupError.processFailed
        }
        return (loggedIn, method)
    }

    private func writeLauncher(named name: String, contents: String) throws -> URL {
        try FileManager.default.createDirectory(
            at: launcherDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let url = launcherDirectory.appending(path: "\(name).command")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: url.path
        )
        return url
    }

    private func openInTerminal(_ launcherURL: URL) async throws {
        let didOpen = await terminalOpener.open(launcherURL)
        guard didOpen else {
            throw ClaudeCLISetupError.couldNotOpenTerminal
        }
    }
}
