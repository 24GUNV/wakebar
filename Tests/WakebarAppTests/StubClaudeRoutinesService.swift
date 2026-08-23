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

    init(routines: [ClaudeRoutine] = []) {
        self.routines = routines
    }

    func listRoutines() async throws -> [ClaudeRoutine] {
        routines
    }

    func createRoutine(_ spec: RoutineSpec, environmentID: String) async throws {
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

    func updateRoutine(id: String, spec: RoutineSpec, environmentID: String) async throws {}

    func disableRoutine(id: String) async throws {}

    func runRoutine(id: String) async throws {
        runIDs.append(id)
    }

    func environments() async throws -> [ClaudeEnvironment] {
        [ClaudeEnvironment(id: "cloud", kind: "anthropic_cloud")]
    }
}
