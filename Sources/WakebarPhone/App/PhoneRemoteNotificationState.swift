enum PhoneRemoteNotificationState: Equatable {
    case registering
    case registered
    case failed(String)

    var displayName: String {
        switch self {
        case .registering:
            "Registering"
        case .registered:
            "Registered"
        case .failed:
            "Unavailable"
        }
    }

    var issue: String? {
        if case let .failed(message) = self {
            message
        } else {
            nil
        }
    }
}
