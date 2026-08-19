#if canImport(CloudKit)
import CloudKit
import Foundation

public enum CloudKitPhoneScheduleRepositoryError: LocalizedError, Sendable {
    case noAccount
    case restricted
    case accountStatusUnavailable
    case temporarilyUnavailable
    case malformedRecord
    case concurrentWriterConflict

    public var errorDescription: String? {
        switch self {
        case .noAccount:
            "Sign in to iCloud to receive the Wakebar schedule."
        case .restricted:
            "This iCloud account cannot use Wakebar schedule sync."
        case .accountStatusUnavailable:
            "Wakebar could not check the iCloud account."
        case .temporarilyUnavailable:
            "iCloud schedule sync is temporarily unavailable."
        case .malformedRecord:
            "The iCloud schedule record is incomplete or inconsistent."
        case .concurrentWriterConflict:
            "Another Mac updated this Wakebar schedule. Refresh before publishing again."
        }
    }
}
#endif
