import Foundation

actor FoundationCLICommandRunner: CLICommandRunning {
    func run(
        executableURL: URL,
        arguments: [String],
        timeout: Duration
    ) async throws -> CLICommandResult {
        let outputURL = FileManager.default.temporaryDirectory
            .appending(path: "wakebar-command-\(UUID().uuidString).log")
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let outputHandle = try FileHandle(forWritingTo: outputURL)
        defer {
            try? outputHandle.close()
            try? FileManager.default.removeItem(at: outputURL)
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = outputHandle
        process.standardError = outputHandle
        try process.run()

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        do {
            while process.isRunning {
                try Task.checkCancellation()
                guard clock.now < deadline else {
                    process.terminate()
                    process.waitUntilExit()
                    throw CLICommandRunnerError.timedOut
                }
                try await Task.sleep(for: .milliseconds(50))
            }
        } catch is CancellationError {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
            throw CLICommandRunnerError.cancelled
        }

        try outputHandle.synchronize()
        let output = try String(contentsOf: outputURL, encoding: .utf8)
        return CLICommandResult(status: process.terminationStatus, output: output)
    }
}
