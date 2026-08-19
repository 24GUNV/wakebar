enum LaunchAtLoginState: Equatable {
    case off
    case on
    case requiresApproval
    case unavailable

    var displayName: String {
        switch self {
        case .off:
            "Off"
        case .on:
            "On"
        case .requiresApproval:
            "Approval required"
        case .unavailable:
            "Unavailable"
        }
    }
}
