import Foundation
import Observation
import WakebarCore

/// Runs the Codex wake from this Mac.
///
/// Claude's sessions live in the cloud as Routines. Codex has nothing like
/// that Wakebar can write to, so its wake is a request the app sends itself,
/// on this machine, only while it is running. Each tick reads the limits,
/// asks the planner whether a wake is due, sends it, and reads again to see
/// whether the window opened. Nothing here says a window started until Codex
/// reports one.
@MainActor
@Observable
final class CodexWakeModel {
    enum State: Equatable {
        case idle
        case sending
        /// Codex answered but the reading taken afterwards did not show a
        /// new window yet.
        case sent(Date)
        /// Codex reported the window the wake opened.
        case confirmed(UsageWindow, at: Date)
        case failed(String, at: Date)
    }

    private(set) var state: State = .idle
    private(set) var isSignedIn = false
    private(set) var lastHandledAt: Date?
    private(set) var nextCheckAt: Date?

    @ObservationIgnored private let usageReader: any ProviderUsageReading
    @ObservationIgnored private let requester: any CodexStartRequesting
    @ObservationIgnored private let planner: CodexWakePlanner
    @ObservationIgnored private let detector = UsageWindowStartDetector()
    @ObservationIgnored private let credentialCheck: @Sendable () -> Bool
    @ObservationIgnored private let sleeper: any UsageWindowPollingSleeping
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let confirmationDelay: TimeInterval

    private static let lastHandledKey = "codexWake.lastHandledAt"

    init(
        usageReader: (any ProviderUsageReading)? = nil,
        requester: (any CodexStartRequesting)? = nil,
        planner: CodexWakePlanner = CodexWakePlanner(),
        credentialCheck: (@Sendable () -> Bool)? = nil,
        sleeper: any UsageWindowPollingSleeping = ContinuousClockUsageWindowPollingSleeper(),
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = { .now },
        confirmationDelay: TimeInterval = 20
    ) {
        self.usageReader = usageReader ?? CodexUsageAPIClient()
        self.requester = requester ?? CodexPingClient()
        self.planner = planner
        self.credentialCheck = credentialCheck ?? {
            (try? UsageWindowCredentialResolver().codexCredential()) != nil
        }
        self.sleeper = sleeper
        self.defaults = defaults
        self.now = now
        self.confirmationDelay = confirmationDelay
        let stored = defaults.double(forKey: Self.lastHandledKey)
        lastHandledAt = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    func refreshSignIn() {
        isSignedIn = credentialCheck()
    }

    /// One evaluation. Returns when the next one is worth running, or nil
    /// when the schedule gives Codex nothing to do.
    @discardableResult
    func tick(schedule: WakeSchedule) async -> Date? {
        refreshSignIn()
        let readAt = now()
        let windows = (try? await usageReader.currentWindows(now: readAt)) ?? []
        let decision = planner.decide(
            schedule: schedule,
            windows: windows,
            now: readAt,
            lastHandledAt: lastHandledAt
        )
        nextCheckAt = decision.nextCheck

        guard decision.firesNow else {
            // A slot whose window the user already opened is settled without
            // a request; otherwise it would stay pending all day.
            if let dueAt = decision.dueAt {
                recordHandled(dueAt)
            }
            return decision.nextCheck
        }

        state = .sending
        do {
            _ = try await requester.requestStart(prompt: ProviderID.codex.minimalPrompt)
        } catch {
            state = .failed(Self.failureMessage(for: error), at: now())
            return decision.nextCheck
        }
        let sentAt = now()
        recordHandled(decision.dueAt ?? sentAt)
        state = .sent(sentAt)

        try? await sleeper.sleep(for: .seconds(confirmationDelay))
        let confirmedAt = now()
        if let current = try? await usageReader.currentWindows(now: confirmedAt),
           let started = detector.startedWindow(baseline: windows, current: current, provider: .codex) {
            state = .confirmed(started, at: confirmedAt)
        }
        return decision.nextCheck
    }

    private func recordHandled(_ date: Date) {
        lastHandledAt = date
        defaults.set(date.timeIntervalSince1970, forKey: Self.lastHandledKey)
    }

    private static func failureMessage(for error: any Error) -> String {
        if let issue = error as? UsageWindowProviderIssue {
            return issue.message(for: .codex)
        }
        guard let apiError = error as? UsageWindowAPIError else {
            return "Codex did not answer the request."
        }
        return switch apiError {
        case .unauthorized, .forbidden:
            UsageWindowProviderIssue.unauthorized.message(for: .codex)
        case .rateLimited:
            "Codex refused the request as too frequent."
        case .network:
            "Codex could not be reached."
        case .invalidResponse:
            "Codex cut the request off before answering."
        }
    }
}
