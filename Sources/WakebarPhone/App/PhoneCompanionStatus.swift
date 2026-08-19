enum PhoneCompanionStatus: Equatable {
    case waitingForSchedule
    case permissionRequired
    case readyToSet
    case permissionDenied
    case scheduling
    case armed
    case alarmMissing
    case inactive
    case unavailable(String)
    case failed(String)

    var title: String {
        switch self {
        case .waitingForSchedule: "Waiting for Wakebar"
        case .permissionRequired: "Permission needed"
        case .readyToSet: "Ready to set"
        case .permissionDenied: "Alarm access is off"
        case .scheduling: "Setting alarm…"
        case .armed: "Alarm is set"
        case .alarmMissing: "Alarm needs resetting"
        case .inactive: "Alarm is off"
        case .unavailable: "Alarm unavailable"
        case .failed: "Could not set alarm"
        }
    }

    var detail: String {
        switch self {
        case .waitingForSchedule:
            "Open Wakebar on your Mac to publish a schedule through iCloud."
        case .permissionRequired:
            "Allow Wakebar to create a system alarm on this iPhone."
        case .readyToSet:
            "Alarm access is on. Set the synced schedule on this iPhone."
        case .permissionDenied:
            "Allow alarms for Wakebar in Settings, then return here."
        case .scheduling:
            "Wakebar is registering the latest schedule with AlarmKit."
        case .armed:
            "AlarmKit has accepted the current schedule on this iPhone."
        case .alarmMissing:
            "The scheduled alarm is no longer registered with iOS."
        case .inactive:
            "The synced Wakebar schedule does not request an iPhone alarm."
        case let .unavailable(reason), let .failed(reason):
            reason
        }
    }

    var systemImage: String {
        switch self {
        case .waitingForSchedule: "icloud.and.arrow.down"
        case .permissionRequired: "bell.badge.fill"
        case .readyToSet: "alarm"
        case .permissionDenied: "bell.slash.fill"
        case .scheduling: "arrow.triangle.2.circlepath"
        case .armed: "alarm.fill"
        case .alarmMissing: "exclamationmark.triangle.fill"
        case .inactive: "alarm"
        case .unavailable: "exclamationmark.triangle.fill"
        case .failed: "xmark.circle.fill"
        }
    }
}
