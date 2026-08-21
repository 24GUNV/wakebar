import AppKit
import SwiftUI
import WakebarCore

/// The settings window: one grouped form, one row grammar — the label on the
/// left, the value or the control on the right — and one bottom bar that owns
/// every message about the draft.
///
/// Nothing beside a control explains it. Validation, unsaved state, and
/// transient notices all resolve to a single status line next to the Save
/// button, which is the only place in the window where a message can appear.
struct ScheduleSettingsView: View {
    @Bindable var model: AppModel
    @State private var draft: WakeSchedule
    @State private var wakeTime: Date
    @State private var providerSetupRequest: ProviderSetupRequest?
    @State private var pendingCleanupProviders: [ProviderID] = []
    @State private var acknowledgedCleanupProvider: ProviderID?
    @State private var isAdvancedExpanded = false

    init(model: AppModel) {
        self.model = model
        let schedule = model.schedule
        _draft = State(initialValue: schedule)
        _wakeTime = State(initialValue: Self.wakeTime(for: schedule))
    }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                scheduleSection
                servicesSection
                alarmSection
                advancedSection
            }
            .formStyle(.grouped)
            .frame(
                minWidth: WakebarDesign.windowMinimumWidth,
                minHeight: WakebarDesign.windowMinimumHeight
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
            .sheet(item: $providerSetupRequest, onDismiss: handleProviderSheetDismissal) { request in
                ProviderSetupSectionView(
                    model: model,
                    provider: request.provider,
                    purpose: request.purpose,
                    onCleanupConfirmed: {
                        acknowledgedCleanupProvider = request.provider
                        providerSetupRequest = nil
                    }
                )
            }
            .onAppear {
                NSApplication.shared.activate()
            }
            .task {
                await model.load()
                apply(model.schedule)
                revealAdvancedIfNeeded(for: model.settingsDestination)
                proxy.scrollTo(model.settingsDestination, anchor: .top)
            }
            .onChange(of: model.settingsDestination) { _, destination in
                revealAdvancedIfNeeded(for: destination)
                proxy.scrollTo(destination, anchor: .top)
            }
            .onChange(of: model.settingsNavigationRequestID) {
                revealAdvancedIfNeeded(for: model.settingsDestination)
                proxy.scrollTo(model.settingsDestination, anchor: .top)
            }
            .onChange(of: model.schedule) { oldSchedule, newSchedule in
                if draft == oldSchedule {
                    apply(newSchedule)
                }
            }
            .onChange(of: wakeTime) { _, newValue in
                applyWakeTime(newValue)
            }
            .onChange(of: draft.followsSystemTimeZone) {
                wakeTime = Self.wakeTime(for: draft)
            }
            .onChange(of: draft.timeZoneIdentifier) {
                wakeTime = Self.wakeTime(for: draft)
            }
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        Section("Schedule") {
            DatePicker(
                "Wake time",
                selection: $wakeTime,
                displayedComponents: .hourAndMinute
            )
            .environment(\.timeZone, draft.timeZone)

            LabeledContent("Days") {
                WeekdayPicker(selection: $draft.selectedWeekdays)
            }

            Picker("Start sessions", selection: $draft.sessionLeadMinutes) {
                Text("5 minutes before").tag(5)
                Text("10 minutes before").tag(10)
                Text("15 minutes before").tag(15)
                Text("30 minutes before").tag(30)
            }

            LabeledContent("Next wake") {
                if let nextWake = draftNextWake {
                    Text(
                        nextWake,
                        format: .dateTime
                            .weekday(.abbreviated)
                            .month(.abbreviated)
                            .day()
                            .hour()
                            .minute()
                    )
                    .environment(\.timeZone, draft.timeZone)
                } else {
                    Text("Not scheduled")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .id(SettingsDestination.schedule)
    }

    // MARK: - Services

    private var servicesSection: some View {
        Section {
            serviceRow(provider: .claude, isOn: $draft.includeClaude)
            serviceRow(provider: .codex, isOn: $draft.includeCodex)
        } header: {
            Text("Services")
        } footer: {
            Text("Sessions run in the provider’s cloud, so this Mac can stay off.")
        }
        .id(SettingsDestination.providers)
    }

    private func serviceRow(provider: ProviderID, isOn: Binding<Bool>) -> some View {
        ProviderSettingsRow(
            title: provider.displayName,
            badge: model.providerIsExperimental(provider) ? "Experimental" : nil,
            status: model.providerMenuStatus(for: provider),
            statusKind: model.providerMenuStatusKind(for: provider),
            actionTitle: model.isProviderReady(provider) ? "Manage…" : "Set Up…",
            isActionEnabled: canRunSetup(for: provider),
            actionHelp: canRunSetup(for: provider)
                ? "Finish this service’s one-time setup with the provider."
                : "Save the schedule before running setup.",
            action: {
                providerSetupRequest = ProviderSetupRequest(provider: provider, purpose: .setup)
            },
            isOn: isOn
        )
    }

    /// Setup writes the saved schedule into the provider, so it cannot run
    /// against times the user has changed but not saved.
    private func canRunSetup(for provider: ProviderID) -> Bool {
        model.schedule.isEnabled && draft.hasSameHostedSetup(as: model.schedule, for: provider)
    }

    // MARK: - iPhone alarm

    private var alarmSection: some View {
        Section("iPhone Alarm") {
            Toggle("Ring on iPhone", isOn: $draft.alarmOnIPhone)
                .disabled(!draft.followsSystemTimeZone && !draft.alarmOnIPhone)
                .help(alarmHelpText)

            if draft.alarmOnIPhone {
                LabeledContent("Delivery") {
                    HStack(spacing: WakebarDesign.compactSpacing) {
                        WindowStatusValue(
                            text: model.phoneAlarmMenuStatus,
                            kind: model.phoneAlarmServiceStatusKind
                        )

                        alarmActionButton
                    }
                }

                if case let .failed(message) = model.phoneAlarmPublishState {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .id(SettingsDestination.alarm)
    }

    @ViewBuilder
    private var alarmActionButton: some View {
        switch model.phoneAlarmPublishState {
        case .published:
            Button("Check iPhone") {
                Task {
                    await model.refreshPhoneAcknowledgement()
                }
            }
        case .failed:
            Button("Retry") {
                Task {
                    await model.retryPhoneSchedule()
                }
            }
        case .draft, .publishing, .confirmed:
            EmptyView()
        }
    }

    private var alarmHelpText: String {
        if !draft.followsSystemTimeZone {
            return "iPhone alarms need Follow system time zone."
        }
        return "Your iPhone confirms the alarm once it receives the iCloud schedule."
    }

    // MARK: - Advanced

    private var advancedSection: some View {
        Section(isExpanded: $isAdvancedExpanded) {
            Picker("Sessions", selection: $draft.cadence) {
                Text("Before each wake").tag(SessionCadence.schedule)
                Text("Every time the window resets").tag(SessionCadence.continuous)
            }
            .help("Wakebar reads the reset time from Claude Code and Codex. With none to read it assumes five hours.")

            // The cutoff and the fallback slots only mean anything to a cadence
            // that is pinned to a day. Chained sessions have no day to end.
            if draft.cadence == .schedule {
                Toggle("Keep going through the day", isOn: $draft.repeatEveryFiveHours)

                if draft.repeatEveryFiveHours {
                    Picker("Last session by", selection: $draft.repeatUntilHour) {
                        ForEach(12..<24, id: \.self) { hour in
                            Text(Self.hourLabel(hour)).tag(hour)
                        }
                    }

                    LabeledContent("Fallback starts", value: plannedSessionStarts)
                        .help("When neither CLI reports a window, sessions run at these times instead.")
                }
            }

            Toggle("Follow system time zone", isOn: $draft.followsSystemTimeZone)

            if !draft.followsSystemTimeZone {
                Picker("Time zone", selection: $draft.timeZoneIdentifier) {
                    ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { identifier in
                        Text(identifier.replacing("_", with: " ")).tag(identifier)
                    }
                }
            }

            LaunchAtLoginSectionView(model: model)
        } header: {
            Text("Advanced")
        }
        .id(SettingsDestination.general)
    }

    // MARK: - Bottom bar

    /// The window's only message. Validation, the transient notice, and the
    /// unsaved-draft state all land here rather than beside the control they
    /// refer to, so no row has to grow a sentence.
    private var bottomBar: some View {
        HStack(spacing: WakebarDesign.sectionSpacing) {
            WindowStatusValue(text: draftStatus.text, kind: draftStatus.kind, lineLimit: 2)

            Spacer(minLength: WakebarDesign.sectionSpacing)

            Button(saveButtonTitle, action: saveDraft)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
        }
        .padding(.horizontal, WakebarDesign.windowPadding)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var draftStatus: (text: String, kind: ServiceStatusKind) {
        if let notice = model.activityNotice {
            let isProblem = notice.kind == .error || notice.kind == .warning
            return (notice.message, isProblem ? .actionRequired : .ready)
        }
        if draft.selectedWeekdays.isEmpty {
            return ("Choose at least one day", .actionRequired)
        }
        if draft.providerIDs.isEmpty {
            return ("Choose at least one service", .actionRequired)
        }
        if draft != model.schedule {
            return ("Unsaved changes", .inProgress)
        }
        if !model.schedule.isEnabled {
            // A saved schedule that is switched off is off, not absent. Calling
            // it "Not set up" sends the user to redo work they already did.
            return model.hasSchedule ? ("Off", .inProgress) : ("Not set up", .actionRequired)
        }
        return ("Saved", .ready)
    }

    private var canSave: Bool {
        draft.isValid && (!model.schedule.isEnabled || draft != model.schedule)
    }

    /// Two titles, not three: either saving is the end of it, or a setup sheet
    /// is about to open — which is what the ellipsis promises.
    private var saveButtonTitle: String {
        pendingSetupProvider == nil ? "Save" : "Save and Set Up…"
    }

    // MARK: - Draft

    private var draftNextWake: Date? {
        guard draft.isValid else { return nil }
        var activeDraft = draft
        activeDraft.isEnabled = true
        return ScheduleCalculator().nextWakeOccurrence(after: .now, for: activeDraft)
    }

    private var plannedSessionStarts: String {
        let slots = RecurringSessionSlotCompiler().slots(for: draft)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = draft.timeZone
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = draft.timeZone

        return slots.compactMap { slot in
            calendar.date(
                from: DateComponents(
                    year: 2001,
                    month: 1,
                    day: 1,
                    hour: slot.hour,
                    minute: slot.minute
                )
            )?.formatted(style)
        }.formatted()
    }

    private func saveDraft() {
        applyWakeTime(wakeTime)
        pendingCleanupProviders = draft.providersRemoved(from: model.schedule)
        if let provider = pendingCleanupProviders.first {
            providerSetupRequest = ProviderSetupRequest(provider: provider, purpose: .cleanup)
            return
        }

        saveDraftAfterCleanup()
    }

    private func saveDraftAfterCleanup() {
        let providerToSetUp = pendingSetupProvider
        model.saveSchedule(draft)
        apply(model.schedule)
        if let providerToSetUp {
            providerSetupRequest = ProviderSetupRequest(
                provider: providerToSetUp,
                purpose: .setup
            )
        }
    }

    private func handleProviderSheetDismissal() {
        guard let provider = acknowledgedCleanupProvider else {
            for pendingProvider in pendingCleanupProviders {
                restoreProviderSelection(pendingProvider)
            }
            pendingCleanupProviders = []
            return
        }
        acknowledgedCleanupProvider = nil
        pendingCleanupProviders.removeAll { $0 == provider }

        if let nextProvider = pendingCleanupProviders.first {
            providerSetupRequest = ProviderSetupRequest(
                provider: nextProvider,
                purpose: .cleanup
            )
        } else {
            saveDraftAfterCleanup()
        }
    }

    private func restoreProviderSelection(_ provider: ProviderID) {
        switch provider {
        case .claude:
            draft.includeClaude = true
        case .codex:
            draft.includeCodex = true
        }
    }

    /// The provider whose setup sheet saving will open, if any. The Save button
    /// reads it so its title can promise exactly what happens.
    private var pendingSetupProvider: ProviderID? {
        guard !model.schedule.isEnabled || hasProviderAffectingDraftChanges else { return nil }
        return firstProviderNeedingSetup
    }

    private var firstProviderNeedingSetup: ProviderID? {
        draft.providerIDs.first { provider in
            !model.schedule.isEnabled
                || !draft.hasSameHostedSetup(as: model.schedule, for: provider)
                || !model.isProviderReady(provider)
        }
    }

    private var hasProviderAffectingDraftChanges: Bool {
        let affectedProviders = Set(draft.providerIDs + model.schedule.providerIDs)
        return affectedProviders.contains { provider in
            !draft.hasSameHostedSetup(as: model.schedule, for: provider)
        }
    }

    private func revealAdvancedIfNeeded(for destination: SettingsDestination) {
        if destination == .general {
            isAdvancedExpanded = true
        }
    }

    private func apply(_ schedule: WakeSchedule) {
        draft = schedule
        wakeTime = Self.wakeTime(for: schedule)
    }

    private func applyWakeTime(_ date: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = draft.timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        draft.hour = components.hour ?? draft.hour
        draft.minute = components.minute ?? draft.minute
    }

    private static func wakeTime(for schedule: WakeSchedule) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = schedule.timeZone
        return calendar.date(
            from: DateComponents(
                year: 2001,
                month: 1,
                day: 1,
                hour: schedule.hour,
                minute: schedule.minute
            )
        ) ?? .now
    }

    private static func hourLabel(_ hour: Int) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(
            from: DateComponents(year: 2001, month: 1, day: 1, hour: hour)
        )
        return date?.formatted(date: .omitted, time: .shortened) ?? "\(hour):00"
    }
}
