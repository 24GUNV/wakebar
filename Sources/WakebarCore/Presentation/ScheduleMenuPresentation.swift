public struct ScheduleMenuPresentation: Equatable, Sendable {
    public let state: ScheduleMenuState
    public let statusText: String
    public let primaryActionTitle: String
    public let destination: ScheduleMenuDestination
    public let phoneStatusText: String
    public let phoneStatusKind: ServiceStatusKind

    public static func resolve(
        isEnabled: Bool,
        providersReady: Bool,
        alarmEnabled: Bool,
        phonePhase: PhoneAlarmMenuPhase
    ) -> Self {
        guard isEnabled else {
            return Self(
                state: .draft,
                statusText: "Draft",
                primaryActionTitle: "Set Up Wake Schedule…",
                destination: .schedule,
                phoneStatusText: phoneStatus(for: phonePhase),
                phoneStatusKind: statusKind(for: phonePhase)
            )
        }

        guard providersReady else {
            return Self(
                state: .actionRequired,
                statusText: "Setup required",
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
                statusText: "Syncing…",
                primaryActionTitle: "View Alarm Status…",
                destination: .alarm,
                phoneStatusText: phoneStatus(for: phonePhase),
                phoneStatusKind: .inProgress
            )
        case .published:
            return Self(
                state: .inProgress,
                statusText: "Waiting for iPhone",
                primaryActionTitle: "View Alarm Status…",
                destination: .alarm,
                phoneStatusText: phoneStatus(for: phonePhase),
                phoneStatusKind: .inProgress
            )
        case .draft:
            return Self(
                state: .actionRequired,
                statusText: "Setup required",
                primaryActionTitle: "Finish Setup…",
                destination: .alarm,
                phoneStatusText: phoneStatus(for: phonePhase),
                phoneStatusKind: .actionRequired
            )
        case .failed:
            return Self(
                state: .actionRequired,
                statusText: "Needs attention",
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
            "Setup required"
        case .publishing:
            "Syncing…"
        case .published:
            "Waiting for iPhone"
        case .confirmed:
            "Alarm confirmed"
        case .failed:
            "Needs attention"
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
