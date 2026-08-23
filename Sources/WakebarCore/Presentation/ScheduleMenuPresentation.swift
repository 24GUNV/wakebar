/// The single source of the menu's status vocabulary.
///
/// Every surface — menu bar popover, settings, service rows — reads its status
/// words from here so the same situation is never described two ways.
public struct ScheduleMenuPresentation: Equatable, Sendable {
    public let state: ScheduleMenuState
    public let statusText: String
    public let primaryActionTitle: String
    public let destination: ScheduleMenuDestination

    /// - Parameter hasSchedule: whether a usable schedule exists at all. A
    ///   schedule the user switched off still needs editing, not setting up.
    public static func resolve(
        isEnabled: Bool,
        hasSchedule: Bool = true,
        providersReady: Bool
    ) -> Self {
        guard isEnabled else {
            return Self(
                state: .draft,
                statusText: hasSchedule ? "Off" : "Not set up",
                primaryActionTitle: hasSchedule ? "Edit Schedule…" : "Set Up Schedule…",
                destination: .schedule
            )
        }

        guard providersReady else {
            return Self(
                state: .actionRequired,
                statusText: "Needs setup",
                primaryActionTitle: "Finish Setup…",
                destination: .providers
            )
        }

        return Self(
            state: .ready,
            statusText: "Ready",
            primaryActionTitle: "Edit Schedule…",
            destination: .schedule
        )
    }
}
