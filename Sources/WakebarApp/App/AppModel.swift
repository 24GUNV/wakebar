import Foundation
import Observation
import WakebarCore

@MainActor
@Observable
final class AppModel {
    var schedule: WakeSchedule {
        didSet {
            guard isLoaded else { return }
            scheduleSaveTask?.cancel()
            let scheduleToSave = schedule

            scheduleSaveTask = Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                await persist(scheduleToSave)
            }
        }
    }
    var snapshots: [ProviderSnapshot]
    var activityMessage: String?
    var isRunning = false
    var isLoaded = false
    var isLoading = false

    @ObservationIgnored private let scheduleStore: ScheduleStore
    @ObservationIgnored private let scheduleCalculator: ScheduleCalculator
    @ObservationIgnored private let providerAdapters: [ProviderID: any ProviderAdapter]
    @ObservationIgnored private var scheduleSaveTask: Task<Void, Never>?

    init(
        scheduleStore: ScheduleStore = ScheduleStore(),
        scheduleCalculator: ScheduleCalculator = ScheduleCalculator(),
        providerAdapters: [ProviderID: any ProviderAdapter]? = nil
    ) {
        self.scheduleStore = scheduleStore
        self.scheduleCalculator = scheduleCalculator
        self.providerAdapters = providerAdapters ?? Dictionary(
            uniqueKeysWithValues: ProviderID.allCases.map {
                ($0, DryRunProviderAdapter(id: $0) as any ProviderAdapter)
            }
        )
        schedule = .default
        snapshots = ProviderID.allCases.map(ProviderSnapshot.notConnected)
    }

    var nextWake: Date? {
        guard schedule.isEnabled, schedule.isValid else { return nil }
        return scheduleCalculator.nextWakeOccurrence(after: .now, for: schedule)
    }

    var nextSessionStart: Date? {
        guard schedule.isEnabled, schedule.isValid else { return nil }
        return scheduleCalculator.nextSessionStart(after: .now, for: schedule)
    }

    var selectedProviderSummary: String {
        schedule.providerIDs.map(\.displayName).formatted()
    }

    var executionSummaries: [String] {
        schedule.providerIDs.map { provider in
            "\(provider.displayName): \(schedule.backend(for: provider).statusText(for: provider))"
        }
    }

    var hasSkippedNextWake: Bool {
        guard let skippedWakeDate = schedule.skippedWakeDate else { return false }
        return skippedWakeDate > .now
    }

    func supportedBackends(for provider: ProviderID) -> [ExecutionBackend] {
        switch provider {
        case .claude:
            ExecutionBackend.allCases
        case .codex:
            [.providerCloud, .thisMac, .alwaysOnRunner]
        }
    }

    func load() async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            schedule = try await scheduleStore.load() ?? .default
            if !schedule.isValid {
                schedule.isEnabled = false
            }
        } catch {
            activityMessage = "Could not load the saved schedule."
        }

        isLoaded = true
        await refreshProviders()
    }

    func saveSchedule(_ updatedSchedule: WakeSchedule) {
        schedule = updatedSchedule
    }

    func toggleSkipNextWake() {
        if hasSkippedNextWake {
            schedule.skippedWakeDate = nil
            showTransientMessage("Tomorrow is scheduled again.")
            return
        }

        var scheduleWithoutSkip = schedule
        scheduleWithoutSkip.skippedWakeDate = nil
        guard let wakeDate = scheduleCalculator.nextWakeOccurrence(after: .now, for: scheduleWithoutSkip) else {
            activityMessage = "There is no upcoming wake time to skip."
            return
        }

        schedule.skippedWakeDate = wakeDate
        showTransientMessage("The next wake time is skipped.")
    }

    func refreshProviders() async {
        var refreshed: [ProviderSnapshot] = []

        for provider in ProviderID.allCases {
            guard let adapter = providerAdapters[provider] else { continue }
            refreshed.append(await adapter.probe())
        }

        snapshots = refreshed
    }

    func runNow() async {
        guard !isRunning else { return }

        isRunning = true
        defer { isRunning = false }

        let selectedProviders = schedule.providerIDs
        guard !selectedProviders.isEmpty else {
            activityMessage = "Select at least one provider."
            return
        }

        do {
            for provider in selectedProviders {
                guard let adapter = providerAdapters[provider] else { continue }
                let request = TriggerRequest(
                    scheduleID: schedule.id,
                    plannedFireDate: .now,
                    prompt: provider.minimalPrompt
                )
                _ = try await adapter.preview(request)
            }

            let providers = selectedProviders.map(\.displayName).formatted()
            showTransientMessage("Previewed \(providers). No prompt was sent.")
        } catch {
            activityMessage = "The session-start preview failed."
        }
    }

    private func persist(_ schedule: WakeSchedule) async {
        do {
            try await scheduleStore.save(schedule)
        } catch {
            activityMessage = "Could not save the schedule."
        }
    }

    private func showTransientMessage(_ message: String) {
        activityMessage = message

        Task {
            try? await Task.sleep(for: .seconds(4))
            if activityMessage == message {
                activityMessage = nil
            }
        }
    }
}
