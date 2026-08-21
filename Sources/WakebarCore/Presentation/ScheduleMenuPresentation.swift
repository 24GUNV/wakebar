/// The single source of the menu's status vocabulary.
///
/// Every surface — menu bar popover, settings, service rows — reads its status
/// words from here so the same situation is never described two ways.
public struct ScheduleMenuPresentation: Equatable, Sendable {
    public let state: ScheduleMenuState
    public let statusText: String
    public let primaryActionTitle: String
    public let destination: ScheduleMenuDestination
    public let phoneStatusText: String
    public let phoneStatusKind: ServiceStatusKind

    /// - Parameter hasSchedule: whether a usable schedule exists at all. A
    ///   schedule the user switched off still needs editing, not setting up.
    public static func resolve(
        isEnabled: Bool,
        hasSchedule: Bool = true,
        providersReady: Bool,
        alarmEnabled: Bool,
        phonePhase: PhoneAlarmMenuPhase
    ) -> Self {
        guard isEnabled else {
            return Self(
                state: .draft,
                statusText: hasSchedule ? "Off" : "Not set up",
                primaryActionTitle: hasSchedule ? "Edit Schedule…" : "Set Up Schedule…",
                destination: .schedule,
                phoneStatusText: phoneStatus(for: phonePhase),
                phoneStatusKind: statusKind(for: phonePhase)
            )
        }

        guard providersReady else {
            return Self(
                state: .actionRequired,
                statusText: "Needs setup",
                primaryActionTitle: "Finish Setup…",
                destination: .providers,
                phoneStatusText: phoneStatus(for: phonePhase),
                phoneStatusKind: statusKind(for: phonePhase)
            )
        }

        guard alarmEnabled else {
            return Self(
                state: .ready,
                statusText: "Ready",
                primaryActionTitle: "Edit Schedule…",
                destination: .schedule,
                phoneStatusText: phoneStatus(for: phonePhase),
                phoneStatusKind: statusKind(for: phonePhase)
            )
        }

        switch phonePhase {
        case .confirmed:
            return Self(
                state: .ready,
                statusText: "Ready",
                primaryActionTitle: "Edit Schedule…",
                destination: .schedule,
                phoneStatusText: phoneStatus(for: phonePhase),
                phoneStatusKind: .ready
            )
        case .publishing:
            return Self(
                state: .inProgress,
                statusText: "Syncing",
                primaryActionTitle: "Alarm Status…",
                destination: .alarm,
                phoneStatusText: phoneStatus(for: phonePhase),
                phoneStatusKind: .inProgress
            )
        case .published:
            return Self(
                state: .inProgress,
                statusText: "Waiting for iPhone",
                primaryActionTitle: "Alarm Status…",
                destination: .alarm,
                phoneStatusText: phoneStatus(for: phonePhase),
                phoneStatusKind: .inProgress
            )
        case .draft:
            return Self(
                state: .actionRequired,
                statusText: "Needs setup",
                primaryActionTitle: "Finish Setup…",
                destination: .alarm,
                phoneStatusText: phoneStatus(for: phonePhase),
                phoneStatusKind: .actionRequired
            )
        case .failed:
            return Self(
                state: .actionRequired,
                statusText: "Sync failed",
                primaryActionTitle: "Fix Alarm Sync…",
                destination: .alarm,
                phoneStatusText: phoneStatus(for: phonePhase),
                phoneStatusKind: .actionRequired
            )
        }
    }

    private static func phoneStatus(for phase: PhoneAlarmMenuPhase) -> String {
        switch phase {
        case .draft:
            "Needs setup"
        case .publishing:
            "Syncing"
        case .published:
            "Waiting for iPhone"
        case .confirmed:
            "Ready"
        case .failed:
            "Sync failed"
        }
    }

    private static func statusKind(for phase: PhoneAlarmMenuPhase) -> ServiceStatusKind {
        switch phase {
        case .confirmed:
            .ready
        case .publishing, .published:
            .inProgress
        case .draft, .failed:
            .actionRequired
        }
    }
}
