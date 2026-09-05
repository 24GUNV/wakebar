import WakebarCore
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

actor StubClaudeRoutinesService: ClaudeRoutinesServing {
    private var routines: [ClaudeRoutine]
    private(set) var createdSpecs: [RoutineSpec] = []
    private(set) var runIDs: [String] = []
    private(set) var deletedIDs: [String] = []
    private(set) var credentialIntents: [ClaudeCredentialIntent] = []

    init(routines: [ClaudeRoutine] = []) {
        self.routines = routines
    }

    func listRoutines(
        credentialIntent: ClaudeCredentialIntent
    ) async throws -> [ClaudeRoutine] {
        credentialIntents.append(credentialIntent)
        return routines
    }

    func createRoutine(
        _ spec: RoutineSpec,
        environmentID: String,
        credentialIntent: ClaudeCredentialIntent
    ) async throws {
        credentialIntents.append(credentialIntent)
        createdSpecs.append(spec)
        routines.append(
            ClaudeRoutine(
                id: "created-\(createdSpecs.count)",
                name: spec.name,
                cronExpression: spec.cronExpression,
                enabled: spec.enabled,
                prompt: spec.prompt
            )
        )
    }

    func updateRoutine(
        id: String,
        spec: RoutineSpec,
        environmentID: String,
        credentialIntent: ClaudeCredentialIntent
    ) async throws {
        credentialIntents.append(credentialIntent)
    }

    func deleteRoutine(
        id: String,
        credentialIntent: ClaudeCredentialIntent
    ) async throws {
        credentialIntents.append(credentialIntent)
        deletedIDs.append(id)
        routines.removeAll { $0.id == id }
    }

    func runRoutine(
        id: String,
        credentialIntent: ClaudeCredentialIntent
    ) async throws {
        credentialIntents.append(credentialIntent)
        runIDs.append(id)
    }

    func environments(
        credentialIntent: ClaudeCredentialIntent
    ) async throws -> [ClaudeEnvironment] {
        credentialIntents.append(credentialIntent)
        return [ClaudeEnvironment(id: "cloud", kind: "anthropic_cloud")]
    }
}
