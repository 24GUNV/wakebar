import WakebarCore

protocol ClaudeRoutinesServing: Sendable {
    func listRoutines(credentialIntent: ClaudeCredentialIntent) async throws -> [ClaudeRoutine]
    func createRoutine(
        _ spec: RoutineSpec,
        environmentID: String,
        credentialIntent: ClaudeCredentialIntent
    ) async throws
    func updateRoutine(
        id: String,
        spec: RoutineSpec,
        environmentID: String,
        credentialIntent: ClaudeCredentialIntent
    ) async throws
    func deleteRoutine(id: String, credentialIntent: ClaudeCredentialIntent) async throws
    func runRoutine(id: String, credentialIntent: ClaudeCredentialIntent) async throws
    func environments(credentialIntent: ClaudeCredentialIntent) async throws -> [ClaudeEnvironment]
}
