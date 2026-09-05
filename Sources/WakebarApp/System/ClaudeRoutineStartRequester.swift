import Foundation
import WakebarCore

struct ClaudeRoutineStartRequester: ClaudeStartRequesting {
    private let client: any ClaudeRoutinesServing
    private let reconciler: ClaudeRoutineReconciler
    private let planCompiler: RoutinePlanCompiler
    private let now: @Sendable () -> Date

    init(
        client: (any ClaudeRoutinesServing)? = nil,
        planCompiler: RoutinePlanCompiler = RoutinePlanCompiler(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        let resolvedClient = client ?? ClaudeRoutinesClient()
        self.client = resolvedClient
        reconciler = ClaudeRoutineReconciler(client: resolvedClient)
        self.planCompiler = planCompiler
        self.now = now
    }

    func requestStart(for schedule: WakeSchedule) async throws {
        let plan = planCompiler.compile(schedule: schedule, referenceDate: now())
        guard let morningSpec = plan.first(where: { $0.name.hasSuffix(" Morning") }) else {
            throw ClaudeRoutinesError.missingMorningRoutine
        }

        var routine = try await managedMorning(named: morningSpec.name)
        if routine == nil {
            _ = try await reconciler.reconcile(
                plan: plan,
                namePrefix: RoutinePlanCompiler.familyPrefix,
                credentialIntent: .userInitiated
            )
            routine = try await managedMorning(named: morningSpec.name)
        }

        guard let routine else {
            throw ClaudeRoutinesError.missingMorningRoutine
        }
        try await client.runRoutine(
            id: routine.id,
            credentialIntent: .userInitiated
        )
    }

    private func managedMorning(named name: String) async throws -> ClaudeRoutine? {
        try await client.listRoutines(credentialIntent: .userInitiated)
            .first { $0.name == name }
    }
}
