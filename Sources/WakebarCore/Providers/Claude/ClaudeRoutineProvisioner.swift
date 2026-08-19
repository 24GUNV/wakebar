import Foundation

public struct ClaudeRoutineProvisioner: Sendable {
    public static let maximumPromptLength = 65_536

    public init() {}

    public func makePlan(for request: ClaudeRoutineScheduleRequest) throws -> ClaudeRoutineProvisioningPlan {
        guard request.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw ClaudeRoutineProvisioningError.emptyName
        }
        guard (0..<24).contains(request.hour), (0..<60).contains(request.minute) else {
            throw ClaudeRoutineProvisioningError.invalidTime
        }
        guard request.weekdays.isEmpty == false else {
            throw ClaudeRoutineProvisioningError.noWeekdays
        }
        guard TimeZone(identifier: request.timeZoneIdentifier) != nil else {
            throw ClaudeRoutineProvisioningError.invalidTimeZone
        }

        return ClaudeRoutineProvisioningPlan(
            capability: .current,
            managementURL: Self.managementURL,
            routineName: request.name,
            savedPrompt: request.prompt.savedPrompt,
            hour: request.hour,
            minute: request.minute,
            weekdays: request.weekdays,
            timeZoneIdentifier: request.timeZoneIdentifier,
            userActions: [
                "Create a cloud Routine in Claude Code.",
                "Copy this name, prompt, time, weekdays, and time zone into the Routine.",
                "Remove repositories and connectors because this Routine does not need them.",
                "Add an API trigger only if Wakebar should also offer Run now. Store its token in this Mac's Keychain."
            ],
            limitations: [
                "Wakebar cannot create or edit a Claude Routine through a public API.",
                "Claude can start a scheduled run a few minutes after the selected time.",
                "Each successful run uses Claude Code subscription capacity and counts toward applicable Routine limits."
            ]
        )
    }

    private static var managementURL: URL {
        guard let url = URL(string: "https://claude.ai/code/routines") else {
            preconditionFailure("The Claude Routines URL is invalid.")
        }
        return url
    }
}
