public enum CodexSchedulingCatalog {
    public static func capabilities(
        cliAvailability: CodexCLIAvailability = .notChecked
    ) -> [CodexSchedulingCapability] {
        [
            CodexSchedulingCapability(
                route: .chatGPTWebTask,
                status: .conditional("Scheduled tasks must be enabled for the ChatGPT workspace."),
                hostRequirement: .openAIHosted,
                scheduleManager: .chatGPT,
                canAccessLocalProjectFiles: false
            ),
            CodexSchedulingCapability(
                route: .desktopProjectTask,
                status: .conditional("Scheduled tasks must be enabled and configured in the ChatGPT desktop app."),
                hostRequirement: .thisMac(appMustBeRunning: true),
                scheduleManager: .chatGPT,
                canAccessLocalProjectFiles: true
            ),
            CodexSchedulingCapability(
                route: .localCLI,
                status: localCLIStatus(for: cliAvailability),
                hostRequirement: .thisMac(appMustBeRunning: false),
                scheduleManager: .external,
                canAccessLocalProjectFiles: true
            ),
            CodexSchedulingCapability(
                route: .alwaysOnRunner,
                status: .experimental("Requires a trusted runner, external scheduling, and durable Codex authentication."),
                hostRequirement: .externalRunner,
                scheduleManager: .external,
                canAccessLocalProjectFiles: false
            ),
        ]
    }

    private static func localCLIStatus(for availability: CodexCLIAvailability) -> CodexCapabilityStatus {
        switch availability {
        case .notChecked:
            .conditional("Codex CLI availability and authentication have not been checked.")
        case .notFound:
            .conditional("Install and authenticate Codex CLI before configuring a local job.")
        case .available:
            .experimental("Codex CLI is available, but Wakebar has not installed an external schedule or executed a live prompt.")
        }
    }
}
