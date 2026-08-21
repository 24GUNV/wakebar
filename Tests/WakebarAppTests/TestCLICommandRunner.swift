import Foundation
@testable import Wakebar

actor TestCLICommandRunner: CLICommandRunning {
    enum Behavior: Sendable {
        case result(CLICommandResult)
        case error(CLICommandRunnerError)
    }

    private let behaviors: [String: Behavior]

    init(behaviors: [String: Behavior]) {
        self.behaviors = behaviors
    }

    func run(
        executableURL: URL,
        arguments: [String],
        timeout: Duration
    ) async throws -> CLICommandResult {
        guard let behavior = behaviors[arguments.joined(separator: " ")] else {
            return CLICommandResult(status: 1, output: "unexpected command")
        }
        switch behavior {
        case let .result(result):
            return result
        case let .error(error):
            throw error
        }
    }
}
