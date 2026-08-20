import WakebarCore

enum SettingsDestination: Hashable {
    case general
    case schedule
    case alarm
    case providers

    init(_ destination: ScheduleMenuDestination) {
        switch destination {
        case .schedule:
            self = .schedule
        case .alarm:
            self = .alarm
        case .providers:
            self = .providers
        }
    }
}
