import Foundation

public enum PhoneAlarmCoordinatorError: LocalizedError, Sendable {
    case cancellationFailed
    case replacementRestoredWithCleanupPending
    case replacementAndRestoreFailed

    public var errorDescription: String? {
        switch self {
        case .cancellationFailed:
            "Wakebar could not remove every managed alarm. Try again before relying on this schedule."
        case .replacementRestoredWithCleanupPending:
            "Wakebar restored the previous alarm, but another managed alarm still needs removal."
        case .replacementAndRestoreFailed:
            "Wakebar could not set the new alarm or restore the previous alarm."
        }
    }
}
