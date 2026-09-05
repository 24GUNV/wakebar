import WakebarCore

struct ClaudeRoutineReconciler: Sendable {
    private let client: any ClaudeRoutinesServing

    init(client: any ClaudeRoutinesServing = ClaudeRoutinesClient()) {
        self.client = client
    }

    func reconcile(
        plan: [RoutineSpec],
        namePrefix: String,
        credentialIntent: ClaudeCredentialIntent
    ) async throws -> ClaudeRoutineSyncResult {
        let routines = try await client.listRoutines(credentialIntent: credentialIntent)
        let managed = routines
            .filter { $0.name.hasPrefix(namePrefix) }
            .sorted { $0.id < $1.id }

        var routinesByName = Dictionary(grouping: managed, by: \.name)
        var consumedIDs = Set<String>()
        var environmentID: String?
        var createdCount = 0
        var updatedCount = 0

        for spec in plan {
            guard var candidates = routinesByName[spec.name], !candidates.isEmpty else {
                let resolvedEnvironmentID = try await resolveEnvironmentID(
                    &environmentID,
                    credentialIntent: credentialIntent
                )
                try await client.createRoutine(
                    spec,
                    environmentID: resolvedEnvironmentID,
                    credentialIntent: credentialIntent
                )
                createdCount += 1
                continue
            }
            let existing = candidates.removeFirst()
            routinesByName[spec.name] = candidates

            consumedIDs.insert(existing.id)
            if needsUpdate(existing, to: spec) {
                let resolvedEnvironmentID = try await resolveEnvironmentID(
                    &environmentID,
                    credentialIntent: credentialIntent
                )
                try await client.updateRoutine(
                    id: existing.id,
                    spec: spec,
                    environmentID: resolvedEnvironmentID,
                    credentialIntent: credentialIntent
                )
                updatedCount += 1
            }
        }

        // Anything Wakebar wrote that the plan no longer names is deleted,
        // switched off or not. A disabled leftover is still clutter in the
        // provider's list, and nothing in it is worth keeping: the plan can
        // recreate every Routine from the schedule alone.
        let extras = managed.filter { !consumedIDs.contains($0.id) }
        for routine in extras {
            try await client.deleteRoutine(
                id: routine.id,
                credentialIntent: credentialIntent
            )
        }

        return ClaudeRoutineSyncResult(
            routineCount: plan.count,
            createdCount: createdCount,
            updatedCount: updatedCount,
            deletedCount: extras.count
        )
    }

    private func needsUpdate(_ routine: ClaudeRoutine, to spec: RoutineSpec) -> Bool {
        routine.name != spec.name
            || routine.cronExpression != spec.cronExpression
            || routine.enabled != spec.enabled
            || routine.prompt != spec.prompt
    }

    private func resolveEnvironmentID(
        _ cachedID: inout String?,
        credentialIntent: ClaudeCredentialIntent
    ) async throws -> String {
        if let cachedID {
            return cachedID
        }
        let environments = try await client.environments(credentialIntent: credentialIntent)
        guard let environment = environments.first(where: { $0.kind == "anthropic_cloud" }) else {
            throw ClaudeRoutinesError.missingCloudEnvironment
        }
        cachedID = environment.id
        return environment.id
    }
}
