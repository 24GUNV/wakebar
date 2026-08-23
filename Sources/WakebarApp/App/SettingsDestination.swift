import WakebarCore

enum SettingsDestination: Hashable {
    case general
    case schedule
    case providers

    init(_ destination: ScheduleMenuDestination) {
        switch destination {
        case .schedule:
            self = .schedule
        case .providers:
            self = .providers
        }
    }
}
