import Foundation

public enum PhoneAlarmClientError: LocalizedError, Equatable, Sendable {
    case unavailable(String)

    public var errorDescription: String? {
        switch self {
        case let .unavailable(reason): reason
        }
    }
}
