import Foundation
import Observation
import WakebarCore

@MainActor
@Observable
final class AppModel {
    var schedule: WakeSchedule {
        didSet {
            guard isLoaded, schedule != oldValue else { return }
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
            scheduleSaveTask?.cancel()
            claudeRoutineSyncTask?.cancel()
            let scheduleToSave = schedule

            scheduleSaveTask = Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                await persist(scheduleToSave)
            }

            claudeRoutineSyncTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await syncClaudeRoutines(for: scheduleToSave, showsNotice: true)
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
    var launchAtLoginState: LaunchAtLoginState
    var settingsDestination: SettingsDestination
    var settingsNavigationRequestID: UUID
    var onboardingFlow: OnboardingFlow
    /// A schedule file on disk is the only durable record that setup has been
    /// attempted, so no separate onboarding flag is stored.
    var hasSavedSchedule: Bool
    /// Guards the automatic presentation so reopening the popover cannot raise
    /// the window twice in one launch.
    var hasPresentedOnboarding: Bool
    /// What the CLIs currently report about their own usage windows. Empty
    /// until the first read, and empty forever on a machine where neither CLI
    /// has run — which is why nothing here may be required for a plan.
    var usageWindows: [UsageWindow]
    /// Why a provider has no live session window, when the API can say.
    var usageWindowIssues: [ProviderID: UsageWindowProviderIssue]
    var providerStartNowStates: [ProviderID: ProviderStartNowState]
    let claudeSetup: ClaudeSetupModel
    let codexSetup: CodexSetupModel

    @ObservationIgnored private let scheduleStore: ScheduleStore
    @ObservationIgnored private let scheduleCalculator: ScheduleCalculator
    @ObservationIgnored private let schedulePlanner: SchedulePlanner
    @ObservationIgnored private let providerAdapters: [ProviderID: any ProviderAdapter]
    @ObservationIgnored private let providerDeliveryStore: ProviderDeliveryStore
    @ObservationIgnored private let launchAtLoginService: LaunchAtLoginService
    @ObservationIgnored private let usageWindowReader: any UsageWindowReading
    @ObservationIgnored private let startNowCoordinator: ProviderStartNowCoordinator
    @ObservationIgnored private let sessionChain = ChainedSessionPlanner()
    @ObservationIgnored private var scheduleSaveTask: Task<Void, Never>?
    @ObservationIgnored private var claudeRoutineSyncTask: Task<Void, Never>?
    @ObservationIgnored private var claudeMaintenanceTask: Task<Void, Never>?
    @ObservationIgnored private var providerStartNowTasks: [ProviderID: Task<Void, Never>] = [:]

    init(
        scheduleStore: ScheduleStore = ScheduleStore(),
        scheduleCalculator: ScheduleCalculator = ScheduleCalculator(),
        schedulePlanner: SchedulePlanner? = nil,
        providerDeliveryStore: ProviderDeliveryStore = ProviderDeliveryStore(),
        launchAtLoginService: LaunchAtLoginService? = nil,
        claudeSetup: ClaudeSetupModel? = nil,
        codexSetup: CodexSetupModel? = nil,
        providerAdapters: [ProviderID: any ProviderAdapter]? = nil,
        usageWindowReader: (any UsageWindowReading)? = nil,
        startNowCoordinator: ProviderStartNowCoordinator = ProviderStartNowCoordinator()
    ) {
        let resolvedLaunchAtLoginService = launchAtLoginService ?? LaunchAtLoginService()
        self.scheduleStore = scheduleStore
        self.scheduleCalculator = scheduleCalculator
        self.schedulePlanner = schedulePlanner ?? SchedulePlanner(calculator: scheduleCalculator)
        self.providerDeliveryStore = providerDeliveryStore
        self.launchAtLoginService = resolvedLaunchAtLoginService
        self.usageWindowReader = usageWindowReader ?? LiveUsageWindowReader()
        self.startNowCoordinator = startNowCoordinator
        self.claudeSetup = claudeSetup ?? ClaudeSetupModel()
        self.codexSetup = codexSetup ?? CodexSetupModel()
        self.providerAdapters = providerAdapters ?? [
            .claude: DryRunProviderAdapter(id: .claude) as any ProviderAdapter,
            .codex: DryRunProviderAdapter(id: .codex) as any ProviderAdapter,
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
        usageWindows = []
        usageWindowIssues = [:]
        providerStartNowStates = Dictionary(
            uniqueKeysWithValues: ProviderID.allCases.map { ($0, .idle) }
        )
        launchAtLoginState = resolvedLaunchAtLoginService.state
        settingsDestination = .schedule
        settingsNavigationRequestID = UUID()
        onboardingFlow = OnboardingFlow(providers: initialSchedule.providerIDs)
        hasSavedSchedule = false
        hasPresentedOnboarding = false
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

    /// Codex tasks remain external. Claude Routines are disabled directly when
    /// the schedule is switched off.
    var hasHostedSessions: Bool {
        schedule.includeCodex && schedule.codexRoute.executionBackend == .providerCloud
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
        schedulePlanner.nextEvents(
            after: .now,
            for: schedule,
            windows: usageWindows,
            readyProviders: readyProviders
        )
    }

    /// The providers whose setup Wakebar has confirmed. A session sent anywhere
    /// else does nothing, so counting down to one states an event that cannot
    /// happen — the row already says "Needs setup" and the footer already offers
    /// to fix it.
    private var readyProviders: Set<ProviderID> {
        Set(ProviderID.allCases.filter(isProviderReady))
    }

    /// The open window the next session is waiting on, if any.
    var governingUsageWindow: UsageWindow? {
        sessionChain.governingWindow(windows: usageWindows, now: .now, provider: .claude)
    }

    /// Every window worth reporting, session windows first and the soonest reset
    /// ahead of the rest. Dates come back unformatted so the view can render
    /// them in the schedule's own time zone.
    var usageWindowRows: [UsageWindowRow] {
        usageWindows
            .filter { $0.isOpen(at: .now) && ($0.provider != .codex || !$0.isSessionWindow) }
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

    func usageSummary(at now: Date) -> UsageSummaryViewModel {
        let events = schedulePlanner.nextEvents(
            after: now,
            for: schedule,
            windows: usageWindows
        )
        return UsageSummaryViewModel(
            enabledProviders: schedule.providerIDs,
            events: events,
            windows: usageWindows,
            issues: visibleUsageWindowIssues,
            now: now
        )
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

    var isCodexTaskConfirmed: Bool {
        get { isProviderReady(.codex) }
        set {
            guard schedule.includeCodex else { return }
            if newValue {
                providerDeliveryStates[.codex] = ProviderDeliveryState(
                    provider: .codex,
                    desiredRevision: desiredRevision,
                    appliedRevision: desiredRevision,
                    phase: .confirmed,
                    lastConfirmedAt: .now,
                    detail: "Task creation confirmed by the user. A task is not a sent prompt."
                )
            } else {
                providerDeliveryStates[.codex] = .draft(
                    provider: .codex,
                    revision: desiredRevision
                )
            }
            saveProviderDeliveryStates()
        }
    }

    var codexTaskConfirmedAt: Date? {
        guard isCodexTaskConfirmed else { return nil }
        return providerDeliveryStates[.codex]?.lastConfirmedAt
    }

    var isScheduleReady: Bool {
        scheduleMenuState == .ready
    }

    var scheduleMenuState: ScheduleMenuState {
        scheduleMenuPresentation.state
    }

    var menuBarIconState: MenuBarIconState {
        MenuBarIconState.resolve(
            isScheduleEnabled: schedule.isEnabled,
            menuState: scheduleMenuState
        )
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
            providersReady: providerReadiness == .ready
        )
    }

    func load() async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let storedSchedule = try await scheduleStore.load()
            hasSavedSchedule = storedSchedule != nil
            var loadedSchedule = storedSchedule ?? .default
            loadedSchedule.skippedWakeDate = nil
            loadedSchedule.claudeBackend = .providerCloud
            loadedSchedule.codexBackend = .providerCloud
            loadedSchedule.codexRoute = .chatGPTWebTask
            if loadedSchedule.isEnabled && !loadedSchedule.isValid {
                loadedSchedule.isEnabled = false
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
        await syncClaudeRoutines(for: schedule, showsNotice: false)
        startClaudeMaintenance()
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
        hasSavedSchedule = true
        showTransientMessage("Schedule saved.")
    }

    var shouldPresentOnboarding: Bool {
        OnboardingLaunchDecision.resolve(
            hasSavedSchedule: hasSavedSchedule,
            hasPresentedThisLaunch: hasPresentedOnboarding
        ) == .present
    }

    /// Restarts the walkthrough from the welcome step, whether it was requested
    /// automatically or manually.
    func beginOnboarding() {
        hasPresentedOnboarding = true
        onboardingFlow = OnboardingFlow(providers: schedule.providerIDs)
    }

    /// The schedule step saves through the same path as the settings window,
    /// then fixes which provider steps follow.
    func completeOnboardingScheduleStep(with draft: WakeSchedule) {
        guard draft.isValid else {
            activityNotice = .error("Choose at least one day and provider before saving.")
            return
        }
        saveSchedule(draft)
        onboardingFlow.setProviders(schedule.providerIDs)
        onboardingFlow.advance()
    }

    func advanceOnboarding() {
        onboardingFlow.advance()
    }

    func retreatOnboarding() {
        onboardingFlow.retreat()
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

    func syncClaudeRoutines() async {
        claudeRoutineSyncTask?.cancel()
        await syncClaudeRoutines(for: schedule, showsNotice: true)
    }

    func startNow(_ provider: ProviderID) {
        providerStartNowTasks[provider]?.cancel()
        providerStartNowStates[provider] = .requested
        let requestedSchedule = schedule

        providerStartNowTasks[provider] = Task {
            defer { providerStartNowTasks[provider] = nil }
            do {
                let outcome = try await startNowCoordinator.requestStart(
                    for: provider,
                    schedule: requestedSchedule
                )
                guard !Task.isCancelled else { return }
                switch outcome {
                case let .started(date):
                    providerStartNowStates[provider] = .started(date)
                    await refreshUsageWindows()
                case .unconfirmed:
                    providerStartNowStates[provider] = .unconfirmed
                }
            } catch is CancellationError {
                return
            } catch {
                providerStartNowStates[provider] = .unconfirmed
                activityNotice = .error(startNowFailureMessage(for: provider))
            }
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

    private func syncClaudeRoutines(
        for syncedSchedule: WakeSchedule,
        showsNotice: Bool
    ) async {
        let result = await claudeSetup.sync(for: syncedSchedule)
        guard schedule.revision == syncedSchedule.revision else { return }

        guard let result else {
            providerDeliveryStates[.claude] = ProviderDeliveryState(
                provider: .claude,
                desiredRevision: desiredRevision,
                phase: .failed,
                detail: claudeSetup.failureMessage
            )
            saveProviderDeliveryStates()
            if showsNotice {
                activityNotice = .error(
                    syncedSchedule.includeClaude
                        ? "Could not sync Claude Routines."
                        : "Could not disable the removed Claude Routines."
                )
            }
            return
        }

        if syncedSchedule.includeClaude {
            providerDeliveryStates[.claude] = ProviderDeliveryState(
                provider: .claude,
                desiredRevision: desiredRevision,
                appliedRevision: desiredRevision,
                phase: .confirmed,
                lastConfirmedAt: .now,
                detail: result.summary
            )
        } else {
            providerDeliveryStates[.claude] = .draft(
                provider: .claude,
                revision: desiredRevision
            )
        }
        saveProviderDeliveryStates()
        if showsNotice {
            showTransientMessage("Claude Routines synced. No prompt was sent.")
        }
    }

    private func startClaudeMaintenance() {
        claudeMaintenanceTask?.cancel()
        claudeMaintenanceTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(5 * 60))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                if await claudeSetup.shouldResync(now: .now) {
                    await syncClaudeRoutines(for: schedule, showsNotice: false)
                }
            }
        }
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

    private func startNowFailureMessage(for provider: ProviderID) -> String {
        switch provider {
        case .claude:
            "Claude did not accept the Routine request. The window was not confirmed."
        case .codex:
            "Wakebar could not prepare ChatGPT. The window was not confirmed."
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
