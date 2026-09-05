import Foundation
import Observation
import WakebarCore

@MainActor
@Observable
final class ClaudeSetupModel {
    var state: ClaudeRoutineSyncState = .idle
    var credentialExpiresAt: Date?
    var credentialHasRefreshToken = false

    @ObservationIgnored private let planCompiler: RoutinePlanCompiler
    @ObservationIgnored private let reconciler: ClaudeRoutineReconciler
    @ObservationIgnored private let credentialStore: ClaudeCredentialStore
    @ObservationIgnored private var lastResolvedAccessToken: String?
    @ObservationIgnored private var lastPlan: [RoutineSpec]?
    @ObservationIgnored private var lastSchedule: WakeSchedule?
    @ObservationIgnored private var lastSyncAttemptAt: Date?

    init(
        planCompiler: RoutinePlanCompiler = RoutinePlanCompiler(),
        reconciler: ClaudeRoutineReconciler = ClaudeRoutineReconciler(),
        credentialStore: ClaudeCredentialStore = .shared
    ) {
        self.planCompiler = planCompiler
        self.reconciler = reconciler
        self.credentialStore = credentialStore
    }

    /// - Parameter chainFiresAt: the next chained fire on an "Every reset"
    ///   schedule, or nil when there is no window to chain to. See
    ///   ``ContinuousChainAnchor``.
    func sync(
        for schedule: WakeSchedule,
        credentialIntent: ClaudeCredentialIntent,
        chainFiresAt: Date? = nil
    ) async -> ClaudeRoutineSyncResult? {
        state = .syncing
        lastSyncAttemptAt = .now
        do {
            let credential = try await credentialStore.credential(credentialIntent)
            lastResolvedAccessToken = credential.accessToken
            credentialExpiresAt = credential.expiresAt
            credentialHasRefreshToken = credential.hasRefreshToken
        } catch let issue as UsageWindowProviderIssue {
            state = .failed(issue.message(for: .claude))
            return nil
        } catch {
            state = .failed("Sign in again in Claude Code (run `claude`)")
            return nil
        }
        let plan = planCompiler.compile(
            schedule: schedule,
            referenceDate: .now,
            chainFiresAt: chainFiresAt
        )
        do {
            let result = try await reconciler.reconcile(
                plan: plan,
                namePrefix: RoutinePlanCompiler.familyPrefix,
                credentialIntent: credentialIntent
            )
            lastPlan = plan
            lastSchedule = schedule
            state = .synced(
                at: .now,
                routineCount: result.routineCount,
                summary: result.summary
            )
            return result
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    var failureMessage: String? {
        guard case let .failed(message) = state else { return nil }
        return message
    }

    var credentialExpiryText: String? {
        guard let credentialExpiresAt else { return nil }
        return "token expires \(credentialExpiresAt.formatted(.relative(presentation: .named, unitsStyle: .wide)))"
    }

    func shouldResync(now: Date) async -> Bool {
        if let lastSchedule, let lastPlan {
            let upcoming = planCompiler.compile(schedule: lastSchedule, referenceDate: now)
            let fixed = lastPlan.filter { !$0.name.hasSuffix(RoutinePlanCompiler.chainRoutineSuffix) }
            if upcoming != fixed { return true }
        }
        let changed: Bool
        // A maintenance poll must never raise the Keychain dialog.
        if let credential = try? await credentialStore.credential(.background) {
            credentialExpiresAt = credential.expiresAt
            credentialHasRefreshToken = credential.hasRefreshToken
            changed = lastSyncAttemptAt != nil
                && lastResolvedAccessToken != credential.accessToken
            if changed {
                lastResolvedAccessToken = credential.accessToken
            }
        } else {
            changed = false
        }

        guard !changed else { return true }
        guard let lastSyncAttemptAt else { return true }
        return now.timeIntervalSince(lastSyncAttemptAt) >= 24 * 60 * 60
    }
}
