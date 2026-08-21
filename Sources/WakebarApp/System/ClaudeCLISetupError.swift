import Foundation

enum ClaudeCLISetupError: LocalizedError, Equatable {
    case executableNotFound
    case invalidVersion
    case updateRequired
    case processFailed
    case processTimedOut
    case couldNotOpenTerminal

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            "Claude Code is not installed."
        case .invalidVersion:
            "Wakebar could not read the Claude Code version."
        case .updateRequired:
            "Claude Code must be updated before it can create Routines."
        case .processFailed:
            "Claude Code did not start correctly."
        case .processTimedOut:
            "Claude Code did not respond."
        case .couldNotOpenTerminal:
            "Wakebar could not open Terminal."
        }
    }
}
