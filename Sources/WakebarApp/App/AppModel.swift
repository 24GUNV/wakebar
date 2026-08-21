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
    /// What the CLIs currently report about their own usage windows. Empty
    /// until the first read, and empty forever on a machine where neither CLI
    /// has run — which is why nothing here may be required for a plan.
    var usageWindows: [UsageWindow]
    /// Why a provider has no live session window, when the API can say.
    var usageWindowIssues: [ProviderID: UsageWindowProviderIssue]
    let claudeSetup: ClaudeSetupModel

    @ObservationIgnored private let scheduleStore: ScheduleStore
    @ObservationIgnored private let scheduleCalculator: ScheduleCalculator
    @ObservationIgnored private let schedulePlanner: SchedulePlanner
    @ObservationIgnored private let providerAdapters: [ProviderID: any ProviderAdapter]
    @ObservationIgnored private let providerDeliveryStore: ProviderDeliveryStore
    @ObservationIgnored private let phoneSchedulePublisher: MacPhoneSchedulePublisher
    @ObservationIgnored private let launchAtLoginService: LaunchAtLoginService
    @ObservationIgnored private let usageWindowReader: any UsageWindowReading
    @ObservationIgnored private let sessionChain = ChainedSessionPlanner()
    @ObservationIgnored private var scheduleSaveTask: Task<Void, Never>?
    @ObservationIgnored private var phoneAcknowledgementTask: Task<Void, Never>?

    init(
        scheduleStore: ScheduleStore = ScheduleStore(),
        scheduleCalculator: ScheduleCalculator = ScheduleCalculator(),
        schedulePlanner: SchedulePlanner? = nil,
        phoneSchedulePublisher: MacPhoneSchedulePublisher = MacPhoneSchedulePublisher(),
        providerDeliveryStore: ProviderDeliveryStore = ProviderDeliveryStore(),
        launchAtLoginService: LaunchAtLoginService? = nil,
        claudeSetup: ClaudeSetupModel? = nil,
        providerAdapters: [ProviderID: any ProviderAdapter]? = nil,
        usageWindowReader: (any UsageWindowReading)? = nil
    ) {
        let resolvedLaunchAtLoginService = launchAtLoginService ?? LaunchAtLoginService()
        self.scheduleStore = scheduleStore
        self.scheduleCalculator = scheduleCalculator
        self.schedulePlanner = schedulePlanner ?? SchedulePlanner(calculator: scheduleCalculator)
        self.phoneSchedulePublisher = phoneSchedulePublisher
        self.providerDeliveryStore = providerDeliveryStore
        self.launchAtLoginService = resolvedLaunchAtLoginService
        self.usageWindowReader = usageWindowReader ?? LiveUsageWindowReader()
        self.claudeSetup = claudeSetup ?? ClaudeSetupModel()
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
        usageWindows = []
        usageWindowIssues = [:]
        launchAtLoginState = resolvedLaunchAtLoginService.state
        settingsDestination = .schedule
        settingsNavigationRequestID = UUID()
    }

    var nextWake: Date? {
        guard schedule.isEnabled, schedule.isValid else { return nil }
        return scheduleCalculator.nextWakeOccurrence(after: .now, for: schedule)
    }

    /// The wake this countdown is measured from, so the progress bar shows how
    /// far through the gap between two wakes the user currently is.
    var previousWake: Date? {
        guard schedule.isEnabled, schedule.isValid else { return nil }
        return scheduleCalculator.previousWakeOccurrence(before: .now, for: schedule)
    }

    /// The master switch. Wakebar has no other way to stand down.
    var isScheduleActive: Bool {
        get { schedule.isEnabled }
        set {
            guard newValue != schedule.isEnabled else { return }
            guard newValue == false || schedule.isValid else {
                activityNotice = .error("Choose at least one day and provider first.")
                return
            }
            schedule.isEnabled = newValue
        }
    }

    /// True once there is a schedule worth showing, whether or not it is running.
    var hasSchedule: Bool {
        schedule.isValid
    }

    /// Wakebar can stop its own alarm, but a Routine or task already created in
    /// a provider's cloud keeps running until the user removes it there.
    var hasHostedSessions: Bool {
        schedule.providerIDs.contains { schedule.backend(for: $0) == .providerCloud }
    }

    var weekdaySummary: String {
        let days = schedule.selectedWeekdays
        if days.isEmpty { return "No days" }
        if days.count == Weekday.allCases.count { return "Every day" }
        if days == Weekday.workweek { return "Weekdays" }
        if days == [.saturday, .sunday] { return "Weekends" }
        return Weekday.displayOrder(for: .autoupdatingCurrent)
            .filter(days.contains)
            .map(\.shortLabel)
            .joined(separator: " ")
    }

    /// The wake time itself, readable even while the schedule is switched off
    /// and there is no next occurrence to format.
    var wakeTimeText: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = schedule.timeZone
        let reference = calendar.date(
            from: DateComponents(
                year: 2001,
                month: 1,
                day: 1,
                hour: schedule.hour,
                minute: schedule.minute
            )
        )
        guard let reference else { return "" }

        let formatter = DateFormatter()
        formatter.timeZone = schedule.timeZone
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter.string(from: reference)
    }

    var plannedEvents: [ScheduledEvent] {
        schedulePlanner.nextEvents(after: .now, for: schedule, windows: usageWindows)
    }

    /// The open window the next session is waiting on, if any.
    var governingUsageWindow: UsageWindow? {
        sessionChain.governingWindow(windows: usageWindows, now: .now)
    }

    /// Every window worth reporting, session windows first and the soonest reset
    /// ahead of the rest. Dates come back unformatted so the view can render
    /// them in the schedule's own time zone.
    var usageWindowRows: [UsageWindowRow] {
        usageWindows
            .filter { $0.isOpen(at: .now) }
            .sorted { lhs, rhs in
                if lhs.isSessionWindow != rhs.isSessionWindow {
                    return lhs.isSessionWindow
                }
                return lhs.resetsAt < rhs.resetsAt
            }
            .map(UsageWindowRow.init)
    }

    /// The cutoff hour to name when nothing reported a session window, so the
    /// fixed cadence the plan fell back to is stated rather than implied.
    var assumedCadenceHour: Int? {
        guard governingUsageWindow == nil,
              schedule.cadence == .schedule,
              schedule.repeatEveryFiveHours
        else { return nil }
        return schedule.repeatUntilHour
    }

    /// The usage band earns its space when there is a window to report or a
    /// chain to explain. On a plain schedule with nothing open it would be three
    /// empty rows, so it stays out.
    var showsUsageBand: Bool {
        if schedule.cadence == .continuous { return true }
        return schedule.repeatEveryFiveHours || !usageWindowRows.isEmpty || !visibleUsageWindowIssues.isEmpty
    }

    /// Only the providers this schedule actually uses. The reader asks both APIs
    /// either way, and telling someone who never set Codex up that its
    /// credentials are missing reports a problem they do not have.
    var visibleUsageWindowIssues: [ProviderID: UsageWindowProviderIssue] {
        usageWindowIssues.filter { schedule.providerIDs.contains($0.key) }
    }

    /// Which clock the sessions run on. The quick switch in the popover writes
    /// here, so flipping it re-plans immediately rather than waiting for a save.
    var sessionCadence: SessionCadence {
        get { schedule.cadence }
        set {
            guard newValue != schedule.cadence else { return }
            schedule.cadence = newValue
        }
    }

    /// The next thing Wakebar actually does, which is what the hero counts down
    /// to. On the schedule that is the wake; chained to the window it is the
    /// session, and the two can be days apart.
    var nextFire: Date? {
        guard schedule.isEnabled, schedule.isValid else { return nil }
        switch schedule.cadence {
        case .schedule:
            return nextWake
        case .continuous:
            return nextSession?.date
        }
    }

    /// Whose session lands next. Two providers hold independent windows, so a
    /// chained plan usually has two different next times and the hero has to say
    /// which one it is counting down to.
    var nextFireProvider: ProviderID? {
        guard schedule.cadence == .continuous else { return nil }
        guard schedule.providerIDs.count > 1 else { return nil }
        guard case .providerSession(let provider, _)? = nextSession?.kind else { return nil }
        return provider
    }

    /// The soonest session of any provider. `plannedEvents` is already sorted,
    /// so the first session in it is the next thing Wakebar sends.
    private var nextSession: ScheduledEvent? {
        plannedEvents.first { event in
            if case .providerSession = event.kind { true } else { false }
        }
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
        isProviderReady(provider) ? "Ready" : "Needs setup"
    }

    func providerMenuStatusKind(for provider: ProviderID) -> ServiceStatusKind {
        isProviderReady(provider) ? .ready : .actionRequired
    }

    /// Codex scheduling is unverified end to end, so its row carries a badge
    /// rather than a status word of its own.
    func providerIsExperimental(_ provider: ProviderID) -> Bool {
        provider == .codex
    }

    /// What the iPhone alarm is doing while the schedule is switched off. Said
    /// as a state word so it fits the same row grammar as everything else,
    /// rather than as a paragraph of apology.
    var stoppedPhoneStatus: String {
        switch phoneAlarmPublishState {
        case .draft, .confirmed:
            "Off"
        case .publishing:
            "Turning off"
        case .published:
            "Waiting for iPhone"
        case .failed:
            "May still ring"
        }
    }

    var stoppedPhoneStatusKind: ServiceStatusKind {
        switch phoneAlarmPublishState {
        case .draft, .confirmed:
            .ready
        case .publishing, .published:
            .inProgress
        case .failed:
            .actionRequired
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
        scheduleMenuPresentation.state
    }

    var relevantSettingsDestination: SettingsDestination {
        SettingsDestination(scheduleMenuPresentation.destination)
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
            hasSchedule: schedule.isValid,
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
        // Usage is not read here. Nothing outside the popover consumes it, and
        // on macOS each uncached Claude read can raise a credential prompt — so
        // reading at launch charges the user a password for a panel they have
        // not opened. The popover takes its own reading when it appears.
        Task {
            await claudeSetup.refresh()
        }
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

    /// A stale or missing usage reading only costs the chain its precision, and
    /// the plan is still a plan without it.
    func refreshUsageWindows() async {
        let now = Date.now
        usageWindows = await usageWindowReader.currentWindows(now: now)
        if let issueReader = usageWindowReader as? any UsageWindowIssueReporting {
            usageWindowIssues = await issueReader.currentUsageWindowIssues()
        } else {
            usageWindowIssues = [:]
        }
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
