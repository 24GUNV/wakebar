import Foundation

protocol CLICommandRunning: Sendable {
    func run(
        executableURL: URL,
        arguments: [String],
        timeout: Duration
    ) async throws -> CLICommandResult
}
