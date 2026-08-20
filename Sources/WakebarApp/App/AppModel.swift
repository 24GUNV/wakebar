import Foundation
import Observation
import WakebarCore

@MainActor
@Observable
final class AppModel {
    var schedule: WakeSchedule {
        didSet {
            guard isLoaded, schedule != oldValue else { return }
            let wasActive = oldValue.isEnabled
            if schedule.isEnabled && !schedule.isValid {
                schedule.isEnabled = false
                activityNotice = .error("Choose at least one day and provider before saving.")
            }
            if schedule.revision == oldValue.revision {
                schedule.revision = UUID()
            }
            desiredRevision = schedule.revision
            let previousDeliveryStates = providerDeliveryStates
            providerDeliveryStates = Dictionary(
                uniqueKeysWithValues: ProviderID.allCases.map { provider in
                    let previousState = previousDeliveryStates[provider]
                    let preservesConfirmation = schedule.hasSameHostedSetup(
                        as: oldValue,
                        for: provider
                    ) && previousState?.isCurrentRevisionConfirmed == true
                    let state = if preservesConfirmation {
                        ProviderDeliveryState(
                            provider: provider,
                            desiredRevision: desiredRevision,
                            appliedRevision: desiredRevision,
                            phase: .confirmed,
                            lastConfirmedAt: previousState?.lastConfirmedAt,
                            detail: previousState?.detail
                        )
                    } else {
                        ProviderDeliveryState.draft(
                            provider: provider,
                            revision: desiredRevision
                        )
                    }
                    return (provider, state)
                }
            )
            saveProviderDeliveryStates()
            let shouldPublishPhoneUpdate = schedule.isEnabled || wasActive
            phoneAlarmPublishState = shouldPublishPhoneUpdate ? .publishing : .draft
            phoneAcknowledgementTask?.cancel()
            scheduleSaveTask?.cancel()
            let scheduleToSave = schedule

            scheduleSaveTask = Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                await persist(scheduleToSave)
                if shouldPublishPhoneUpdate {
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
    var lastConfirmedPhoneAlarm: PhoneAlarmAcknowledgement?
    var launchAtLoginState: LaunchAtLoginState
    var settingsDestination: SettingsDestination
    var settingsNavigationRequestID: UUID

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
        launchAtLoginService: LaunchAtLoginService? = nil,
        providerAdapters: [ProviderID: any ProviderAdapter]? = nil
    ) {
        let resolvedLaunchAtLoginService = launchAtLoginService ?? LaunchAtLoginService()
        self.scheduleStore = scheduleStore
        self.scheduleCalculator = scheduleCalculator
        self.schedulePlanner = schedulePlanner ?? SchedulePlanner(calculator: scheduleCalculator)
        self.phoneSchedulePublisher = phoneSchedulePublisher
        self.providerDeliveryStore = providerDeliveryStore
        self.launchAtLoginService = resolvedLaunchAtLoginService
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
        lastConfirmedPhoneAlarm = nil
        launchAtLoginState = resolvedLaunchAtLoginService.state
        settingsDestination = .schedule
        settingsNavigationRequestID = UUID()
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

    func isProviderReady(_ provider: ProviderID) -> Bool {
        providerDeliveryStates[provider]?.isCurrentRevisionConfirmed == true
    }

    func providerMenuStatus(for provider: ProviderID) -> String {
        guard isProviderReady(provider) else { return "Setup required" }
        return provider == .codex
            ? "Confirmed by you · effect unverified"
            : "Confirmed by you"
    }

    func providerMenuStatusKind(for provider: ProviderID) -> ServiceStatusKind {
        guard isProviderReady(provider) else { return .actionRequired }
        return provider == .codex ? .experimental : .ready
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

        let promptDetail = if schedule.providerIDs.count == 1,
                              let provider = schedule.providerIDs.first {
            "\(provider.displayName) \(provider.hostedPromptDescription)"
        } else {
            "provider-specific minimal prompts"
        }

        return "\(location) · \(promptDetail)"
    }

    var phoneAlarmDetail: String {
        switch phoneAlarmPublishState {
        case .draft:
            "Not synced to iPhone"
        case .publishing:
            lastConfirmedPhoneAlarm == nil
                ? "Updating iCloud"
                : "Updating iCloud · previous alarm remains active"
        case .published:
            lastConfirmedPhoneAlarm == nil
                ? "iCloud updated · awaiting iPhone"
                : "Awaiting iPhone · previous alarm may still ring"
        case let .confirmed(acknowledgement):
            if schedule.isEnabled && schedule.alarmOnIPhone {
                "Confirmed on iPhone · revision \(acknowledgement.revision.sequence)"
            } else {
                "iPhone confirmed the previous alarm is off"
            }
        case let .failed(message):
            lastConfirmedPhoneAlarm == nil
                ? message
                : "\(message) · previous alarm may still ring"
        }
    }

    var draftPhoneStatus: String? {
        guard !schedule.isEnabled else { return nil }
        switch phoneAlarmPublishState {
        case .draft:
            return nil
        case .publishing:
            return "Turning off the previous iPhone alarm…"
        case .published:
            return "Waiting for the iPhone to turn off the previous alarm."
        case .confirmed:
            return "The iPhone confirmed the previous alarm is off."
        case .failed:
            return "Wakebar could not turn off the previous iPhone alarm. It may still ring."
        }
    }

    var phoneAlarmReadiness: ScheduleEventReadiness {
        if case .confirmed = phoneAlarmPublishState {
            .ready
        } else {
            .setupRequired
        }
    }

    var phoneAlarmMenuStatus: String {
        scheduleMenuPresentation.phoneStatusText
    }

    var phoneAlarmServiceStatusKind: ServiceStatusKind {
        scheduleMenuPresentation.phoneStatusKind
    }

    var isScheduleReady: Bool {
        scheduleMenuState == .ready
    }

    var scheduleMenuState: ScheduleMenuState {
        if scheduleMenuPresentation.state == .ready, schedule.includeCodex {
            return .experimental
        }
        return scheduleMenuPresentation.state
    }

    var relevantSettingsDestination: SettingsDestination {
        SettingsDestination(scheduleMenuPresentation.destination)
    }

    var scheduleStatusText: String {
        scheduleMenuState == .experimental
            ? "Experimental"
            : scheduleMenuPresentation.statusText
    }

    var primaryMenuActionTitle: String {
        scheduleMenuPresentation.primaryActionTitle
    }

    func requestSettings(_ destination: SettingsDestination) {
        settingsDestination = destination
        settingsNavigationRequestID = UUID()
    }

    private var scheduleMenuPresentation: ScheduleMenuPresentation {
        ScheduleMenuPresentation.resolve(
            isEnabled: schedule.isEnabled,
            providersReady: providerReadiness == .ready,
            alarmEnabled: schedule.alarmOnIPhone,
            phonePhase: phoneAlarmMenuPhase
        )
    }

    private var phoneAlarmMenuPhase: PhoneAlarmMenuPhase {
        switch phoneAlarmPublishState {
        case .draft:
            .draft
        case .publishing:
            .publishing
        case .published:
            .published
        case .confirmed:
            .confirmed
        case .failed:
            .failed
        }
    }

    func load() async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        var shouldPublishDisabledSchedule = false
        do {
            var loadedSchedule = try await scheduleStore.load() ?? .default
            loadedSchedule.skippedWakeDate = nil
            loadedSchedule.claudeBackend = .providerCloud
            loadedSchedule.codexBackend = .providerCloud
            loadedSchedule.codexRoute = .chatGPTWebTask
            if loadedSchedule.isEnabled && !loadedSchedule.isValid {
                loadedSchedule.isEnabled = false
                shouldPublishDisabledSchedule = true
            }
            schedule = loadedSchedule
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
        if let acknowledgement = try? await phoneSchedulePublisher.acknowledgement(
            for: schedule.id
        ) {
            lastConfirmedPhoneAlarm = acknowledgement
            if !schedule.isEnabled {
                shouldPublishDisabledSchedule = true
            }
        }
        if shouldPublishDisabledSchedule {
            await persist(schedule)
        }
        if schedule.isEnabled || shouldPublishDisabledSchedule {
            await publishPhoneSchedule(schedule)
        }
    }

    func saveSchedule(_ updatedSchedule: WakeSchedule) {
        guard updatedSchedule.isValid else {
            activityNotice = .error("Choose at least one day and provider before saving.")
            return
        }
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

    func claudeSetupInstructions() -> String {
        ProviderSetupPromptCompiler().claudeRoutineInstructions(for: schedule)
    }

    func codexSetupInstructions() -> String {
        ProviderSetupPromptCompiler().chatGPTTaskPrompt(for: schedule)
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
        showTransientMessage("\(provider.displayName) marked as set up.")
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

    func retryPhoneSchedule() async {
        guard schedule.isEnabled, schedule.alarmOnIPhone else { return }
        await publishPhoneSchedule(schedule)
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
        lastConfirmedPhoneAlarm = acknowledgement
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

}
