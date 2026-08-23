import WakebarCore

protocol ClaudeRoutinesServing: Sendable {
    func listRoutines() async throws -> [ClaudeRoutine]
    func createRoutine(_ spec: RoutineSpec, environmentID: String) async throws
    func updateRoutine(id: String, spec: RoutineSpec, environmentID: String) async throws
    func disableRoutine(id: String) async throws
    func runRoutine(id: String) async throws
    func environments() async throws -> [ClaudeEnvironment]
}
