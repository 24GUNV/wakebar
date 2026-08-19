import Foundation
import Observation
import WakebarCore

@MainActor
@Observable
final class AppModel {
    var schedule: WakeSchedule {
        didSet {
            guard isLoaded, schedule != oldValue else { return }
            if schedule.revision == oldValue.revision {
                schedule.revision = UUID()
            }
            desiredRevision = schedule.revision
            providerDeliveryStates = Dictionary(
                uniqueKeysWithValues: ProviderID.allCases.map { provider in
                    (provider, .draft(provider: provider, revision: desiredRevision))
                }
            )
            saveProviderDeliveryStates()
            phoneAlarmPublishState = .draft
            phoneAcknowledgementTask?.cancel()
            scheduleSaveTask?.cancel()
            let scheduleToSave = schedule

            scheduleSaveTask = Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                await persist(scheduleToSave)
                if scheduleToSave.isEnabled {
                    await publishPhoneSchedule(scheduleToSave)
                } else {
                    phoneAlarmPublishState = .draft
                }
            }
        }
    }
    var snapshots: [ProviderSnapshot]
    var activityNotice: ActivityNotice?
    var isRunning = false
    var isLoaded = false
    var isLoading = false
    var desiredRevision: UUID
    var providerDeliveryStates: [ProviderID: ProviderDeliveryState]
    var phoneAlarmPublishState: PhoneAlarmPublishState
    var launchAtLoginState: LaunchAtLoginState

    @ObservationIgnored private let scheduleStore: ScheduleStore
    @ObservationIgnored private let scheduleCalculator: ScheduleCalculator
    @ObservationIgnored private let schedulePlanner: SchedulePlanner
    @ObservationIgnored private let providerAdapters: [ProviderID: any ProviderAdapter]
    @ObservationIgnored private let providerDeliveryStore: ProviderDeliveryStore
    @ObservationIgnored private let phoneSchedulePublisher: MacPhoneSchedulePublisher
    @ObservationIgnored private let launchAtLoginService: LaunchAtLoginService
    @ObservationIgnored private var scheduleSaveTask: Task<Void, Never>?
    @ObservationIgnored private var phoneAcknowledgementTask: Task<Void, Never>?

    init(
        scheduleStore: ScheduleStore = ScheduleStore(),
        scheduleCalculator: ScheduleCalculator = ScheduleCalculator(),
        schedulePlanner: SchedulePlanner? = nil,
        phoneSchedulePublisher: MacPhoneSchedulePublisher = MacPhoneSchedulePublisher(),
        providerDeliveryStore: ProviderDeliveryStore = ProviderDeliveryStore(),
        launchAtLoginService: LaunchAtLoginService = LaunchAtLoginService(),
        providerAdapters: [ProviderID: any ProviderAdapter]? = nil
    ) {
        self.scheduleStore = scheduleStore
        self.scheduleCalculator = scheduleCalculator
        self.schedulePlanner = schedulePlanner ?? SchedulePlanner(calculator: scheduleCalculator)
        self.phoneSchedulePublisher = phoneSchedulePublisher
        self.providerDeliveryStore = providerDeliveryStore
        self.launchAtLoginService = launchAtLoginService
        self.providerAdapters = providerAdapters ?? [
            .claude: DryRunProviderAdapter(id: .claude) as any ProviderAdapter,
            .codex: CodexPreviewProviderAdapter() as any ProviderAdapter,
        ]
        let initialSchedule = WakeSchedule.default
        schedule = initialSchedule
        snapshots = ProviderID.allCases.map(ProviderSnapshot.notConnected)
        let initialRevision = initialSchedule.revision
        desiredRevision = initialRevision
        providerDeliveryStates = Dictionary(
            uniqueKeysWithValues: ProviderID.allCases.map { provider in
                (provider, .draft(provider: provider, revision: initialRevision))
            }
        )
        phoneAlarmPublishState = .draft
        launchAtLoginState = launchAtLoginService.state
    }

    var nextWake: Date? {
        guard schedule.isEnabled, schedule.isValid else { return nil }
        return scheduleCalculator.nextWakeOccurrence(after: .now, for: schedule)
    }

    var plannedEvents: [ScheduledEvent] {
        schedulePlanner.nextEvents(after: .now, for: schedule)
    }

    var nextInitialSessionStart: Date? {
        plannedEvents.first { event in
            if case .providerSession(_, .initial) = event.kind {
                true
            } else {
                false
            }
        }?.date
    }

    var nextPlannedPhoneAlarm: Date? {
        plannedEvents.first { $0.kind == .phoneAlarm }?.date
    }

    var refreshSessionDates: [Date] {
        let sessionDates = plannedEvents.compactMap { event -> Date? in
            if case .providerSession(_, .refresh(index: _)) = event.kind {
                event.date
            } else {
                nil
            }
        }
        let uniqueDates = Array(Set(sessionDates)).sorted()
        return uniqueDates
    }

    var selectedProviderSummary: String {
        schedule.providerIDs.map(\.displayName).formatted()
    }

    var executionSummaries: [String] {
        schedule.providerIDs.map { provider in
            let isConfirmed = providerDeliveryStates[provider]?.isCurrentRevisionConfirmed == true
            let status = isConfirmed ? "confirmed by you" : "setup required"
            return "\(provider.displayName): \(status)"
        }
    }

    var providerReadiness: ScheduleEventReadiness {
        let selectedProviders = Set(schedule.providerIDs)
        guard !selectedProviders.isEmpty else { return .setupRequired }
        let confirmedProviders = Set(
            providerDeliveryStates.compactMap { provider, state in
                state.isCurrentRevisionConfirmed ? provider : nil
            }
        )
        return selectedProviders.isSubset(of: confirmedProviders) ? .ready : .setupRequired
    }

    var sessionExecutionDetail: String {
        let backends = Set(schedule.providerIDs.map { schedule.backend(for: $0) })
        guard !backends.isEmpty else { return "Choose a provider" }
        let location = if backends == [.providerCloud] {
            providerReadiness == .ready ? "Cloud · confirmed by you" : "Cloud · setup required"
        } else if backends == [.thisMac] {
            "Requires this Mac awake"
        } else if backends == [.alwaysOnRunner] {
            "Always-on runner"
        } else {
            "Mixed execution"
        }

        return "\(location) · prompt “hi”"
    }

    var phoneAlarmDetail: String {
        switch phoneAlarmPublishState {
        case .draft:
            "Not synced to iPhone"
        case .publishing:
            "Updating iCloud"
        case .published:
            "iCloud updated · awaiting iPhone"
        case let .confirmed(acknowledgement):
            "Confirmed on iPhone · revision \(acknowledgement.revision.sequence)"
        case let .failed(message):
            message
        }
    }

    var phoneAlarmReadiness: ScheduleEventReadiness {
        if case .confirmed = phoneAlarmPublishState {
            .ready
        } else {
            .setupRequired
        }
    }

    var scheduleStatusText: String {
        guard schedule.isEnabled else { return "Draft" }
        let providersAreReady = providerReadiness == .ready
        let alarmIsReady = !schedule.alarmOnIPhone || phoneAlarmReadiness == .ready
        return providersAreReady && alarmIsReady ? "Ready" : "Setup required"
    }

    func load() async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            var loadedSchedule = try await scheduleStore.load() ?? .default
            loadedSchedule.skippedWakeDate = nil
            loadedSchedule.claudeBackend = .providerCloud
            loadedSchedule.codexBackend = .providerCloud
            loadedSchedule.codexRoute = .chatGPTWebTask
            schedule = loadedSchedule
            if !schedule.isValid {
                schedule.isEnabled = false
            }
        } catch {
            activityNotice = .error("Could not load the saved schedule.")
        }

        desiredRevision = schedule.revision
        do {
            providerDeliveryStates = try await providerDeliveryStore.load(for: schedule.revision)
        } catch {
            providerDeliveryStates = Dictionary(
                uniqueKeysWithValues: ProviderID.allCases.map { provider in
                    (provider, .draft(provider: provider, revision: schedule.revision))
                }
            )
            activityNotice = .error("Could not load provider confirmations.")
        }

        isLoaded = true
        launchAtLoginState = launchAtLoginService.state
        await refreshProviders()
        if schedule.isEnabled {
            await publishPhoneSchedule(schedule)
        }
    }

    func saveSchedule(_ updatedSchedule: WakeSchedule) {
        var scheduleToActivate = updatedSchedule
        scheduleToActivate.isEnabled = true
        scheduleToActivate.skippedWakeDate = nil
        scheduleToActivate.claudeBackend = .providerCloud
        scheduleToActivate.codexBackend = .providerCloud
        scheduleToActivate.codexRoute = .chatGPTWebTask
        schedule = scheduleToActivate
        showTransientMessage("Schedule saved. Syncing the iPhone alarm.")
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
            activityNotice = .error("Select at least one provider.")
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
            activityNotice = .error("The session-start preview failed.")
        }
    }

    func claudeSetupInstructions() throws -> String {
        let plans = try ClaudeRoutineScheduleCompiler().plans(for: schedule)
        let planText = plans.enumerated().map { index, plan in
            """
            \(index + 1). \(plan.routineName)
               Time: \(twoDigit(plan.hour)):\(twoDigit(plan.minute))
               Days: \(weekdayNames(plan.weekdays))
               Time zone: \(plan.timeZoneIdentifier)
               Prompt:
            \(plan.savedPrompt)
            """
        }.joined(separator: "\n\n")

        return """
        Wakebar Claude Code Routine setup

        Create these Routines at https://claude.ai/code/routines.
        Keep repositories and connectors disabled.

        \(planText)

        Scheduled starts can be delayed by a few minutes. Confirm the saved times in Wakebar after setup.
        """
    }

    func codexSetupInstructions() -> String {
        let slots = RecurringSessionSlotCompiler().slots(for: schedule)
        let slotText = slots.enumerated().map { index, slot in
            "\(index + 1). \(twoDigit(slot.hour)):\(twoDigit(slot.minute)) on \(weekdayNames(slot.weekdays))"
        }.joined(separator: "\n")

        return """
        Wakebar Codex setup

        Route: \(schedule.codexRoute.displayName)
        Prompt: hi
        Time zone: \(schedule.timeZone.identifier)

        \(slotText)

        A completed scheduled prompt does not prove that a Codex usage window started or reset.
        """
    }

    func reportCopyResult(_ succeeded: Bool, successMessage: String) {
        if succeeded {
            showTransientMessage(successMessage)
        } else {
            activityNotice = .error("Could not copy the setup instructions.")
        }
    }

    func confirmProviderSchedule(_ provider: ProviderID) {
        providerDeliveryStates[provider] = ProviderDeliveryState(
            provider: provider,
            desiredRevision: desiredRevision,
            appliedRevision: desiredRevision,
            phase: .confirmed,
            lastConfirmedAt: .now,
            detail: "Confirmed manually"
        )
        saveProviderDeliveryStates()
        showTransientMessage("\(provider.displayName) schedule confirmed.")
    }

    func clearProviderConfirmation(_ provider: ProviderID) {
        providerDeliveryStates[provider] = .draft(provider: provider, revision: desiredRevision)
        saveProviderDeliveryStates()
    }

    func refreshPhoneAcknowledgement() async {
        guard case let .published(receipt) = phoneAlarmPublishState else { return }
        if await applyAcknowledgement(for: receipt) {
            showTransientMessage("The iPhone alarm is confirmed.")
        } else {
            showTransientMessage("Still waiting for the iPhone.")
        }
    }

    func enableLaunchAtLogin() {
        updateLaunchAtLogin(isEnabled: true)
    }

    func disableLaunchAtLogin() {
        updateLaunchAtLogin(isEnabled: false)
    }

    func openLoginItemSettings() {
        launchAtLoginService.openLoginItemSettings()
    }

    private func persist(_ schedule: WakeSchedule) async {
        do {
            try await scheduleStore.save(schedule)
        } catch {
            activityNotice = .error("Could not save the schedule.")
        }
    }

    private func publishPhoneSchedule(_ schedule: WakeSchedule) async {
        phoneAlarmPublishState = .publishing
        do {
            let receipt = try await phoneSchedulePublisher.publish(schedule)
            phoneAlarmPublishState = .published(receipt)
            startPhoneAcknowledgementChecks(for: receipt)
        } catch PhoneAlarmScheduleValidationError.fixedTimeZoneUnsupported {
            phoneAlarmPublishState = .failed("Use the system time zone to sync an iPhone alarm.")
        } catch {
            phoneAlarmPublishState = .failed("Could not sync the iPhone alarm.")
        }
    }

    private func startPhoneAcknowledgementChecks(for receipt: PhoneAlarmPublishReceipt) {
        phoneAcknowledgementTask?.cancel()
        phoneAcknowledgementTask = Task {
            var delaySeconds = 0
            while !Task.isCancelled {
                if delaySeconds > 0 {
                    try? await Task.sleep(for: .seconds(delaySeconds))
                }
                guard !Task.isCancelled else { return }

                guard case let .published(currentReceipt) = phoneAlarmPublishState,
                      currentReceipt == receipt
                else { return }

                if await applyAcknowledgement(for: receipt) {
                    return
                }

                delaySeconds = delaySeconds == 0 ? 5 : min(delaySeconds * 2, 300)
            }
        }
    }

    private func applyAcknowledgement(for receipt: PhoneAlarmPublishReceipt) async -> Bool {
        guard let acknowledgement = try? await phoneSchedulePublisher.acknowledgement(
            for: receipt.scheduleID
        ), acknowledgement.revision == receipt.revision
        else { return false }

        phoneAlarmPublishState = .confirmed(acknowledgement)
        return true
    }

    private func saveProviderDeliveryStates() {
        let states = providerDeliveryStates
        Task {
            try? await providerDeliveryStore.save(states)
        }
    }

    private func updateLaunchAtLogin(isEnabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(isEnabled)
            launchAtLoginState = launchAtLoginService.state
        } catch {
            launchAtLoginState = launchAtLoginService.state
            activityNotice = .error("Could not update launch at login.")
        }
    }

    private func showTransientMessage(_ message: String) {
        let notice = ActivityNotice.success(message)
        activityNotice = notice

        Task {
            try? await Task.sleep(for: .seconds(4))
            if activityNotice == notice {
                activityNotice = nil
            }
        }
    }

    private func twoDigit(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private func weekdayNames(_ weekdays: Set<Weekday>) -> String {
        Weekday.displayOrder
            .filter(weekdays.contains)
            .map(\.fullLabel)
            .formatted()
    }
}
