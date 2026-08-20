import AppKit
import SwiftUI
import WakebarCore

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
                Section {
                    VStack(alignment: .leading, spacing: WakebarDesign.sectionSpacing) {
                        HStack(alignment: .top, spacing: WakebarDesign.sectionSpacing) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Wake time")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                DatePicker(
                                    "Wake time",
                                    selection: $wakeTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .controlSize(.large)
                                .font(.title2)
                                .monospacedDigit()
                                .environment(\.timeZone, draft.timeZone)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Next wake")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

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
                                    Text("Complete the schedule")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Divider()

                        Text("Repeat")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        WeekdayPicker(selection: $draft.selectedWeekdays)

                        if draft.selectedWeekdays.isEmpty {
                            Label("Choose at least one day.", systemImage: "exclamationmark.circle")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        Picker("Start sessions", selection: $draft.sessionLeadMinutes) {
                            Text("5 minutes before").tag(5)
                            Text("10 minutes before").tag(10)
                            Text("15 minutes before").tag(15)
                            Text("30 minutes before").tag(30)
                        }
                    }
                }
                .id(SettingsDestination.schedule)

                Section("Services") {
                    serviceEditor(
                        provider: .claude,
                        title: "Claude Code",
                        detail: "Cloud Routine · works while this Mac is off",
                        isOn: $draft.includeClaude
                    )

                    serviceEditor(
                        provider: .codex,
                        title: "Codex — experimental",
                        detail: "ChatGPT task · usage-window effect is unverified",
                        isOn: $draft.includeCodex
                    )

                    if draft.providerIDs.isEmpty {
                        Label("Choose at least one service.", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                    }
                }
                .id(SettingsDestination.providers)

                Section("iPhone alarm") {
                    Toggle("Ring on iPhone", isOn: $draft.alarmOnIPhone)
                        .disabled(!draft.followsSystemTimeZone && !draft.alarmOnIPhone)

                    if draft.alarmOnIPhone {
                        LabeledContent("Delivery") {
                            Text(model.phoneAlarmPublishState.displayName)
                        }

                        Text(alarmHelpText)
                            .foregroundStyle(.secondary)

                        if case .published = model.phoneAlarmPublishState {
                            Button("Check iPhone now") {
                                Task {
                                    await model.refreshPhoneAcknowledgement()
                                }
                            }
                        }

                        if case let .failed(message) = model.phoneAlarmPublishState {
                            Label(message, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)

                            Button("Retry sync", systemImage: "arrow.clockwise") {
                                Task {
                                    await model.retryPhoneSchedule()
                                }
                            }
                        }
                    }
                }
                .id(SettingsDestination.alarm)

                Section {
                    DisclosureGroup("Advanced", isExpanded: $isAdvancedExpanded) {
                        VStack(alignment: .leading, spacing: WakebarDesign.sectionSpacing) {
                            Toggle(
                                "Start another session every 5 hours",
                                isOn: $draft.repeatEveryFiveHours
                            )

                            if draft.repeatEveryFiveHours {
                                Picker("Last session starts by", selection: $draft.repeatUntilHour) {
                                    ForEach(12..<24, id: \.self) { hour in
                                        Text(Self.hourLabel(hour)).tag(hour)
                                    }
                                }

                                LabeledContent("Planned starts", value: plannedSessionStarts)
                            }

                            Divider()

                            Toggle("Follow the system time zone", isOn: $draft.followsSystemTimeZone)

                            if !draft.followsSystemTimeZone {
                                Picker("Time zone", selection: $draft.timeZoneIdentifier) {
                                    ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { identifier in
                                        Text(identifier.replacing("_", with: " ")).tag(identifier)
                                    }
                                }
                            }

                            Divider()

                            LaunchAtLoginSectionView(model: model)
                        }
                    }
                }
                .id(SettingsDestination.general)

                if let activityNotice = model.activityNotice {
                    Section {
                        Text(activityNotice.message)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 520, minHeight: 560)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                saveBar
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

    private var saveBar: some View {
        HStack(spacing: WakebarDesign.sectionSpacing) {
            Text(saveHelpText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            Button(saveButtonTitle, action: saveDraft)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!draft.isValid || (model.schedule.isEnabled && draft == model.schedule))
        }
        .padding(.horizontal, WakebarDesign.horizontalPadding)
        .padding(.vertical, WakebarDesign.compactSpacing)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var draftNextWake: Date? {
        guard draft.isValid else { return nil }
        var activeDraft = draft
        activeDraft.isEnabled = true
        return ScheduleCalculator().nextWakeOccurrence(after: .now, for: activeDraft)
    }

    private var saveButtonTitle: String {
        if !model.schedule.isEnabled {
            return "Save & continue setup"
        }
        return hasProviderAffectingDraftChanges ? "Save & update setup" : "Save changes"
    }

    private var saveHelpText: String {
        if !model.schedule.isEnabled {
            return "Next, Wakebar will help you finish one-time service setup."
        }
        if draft != model.schedule {
            return "Your current schedule stays active until you save."
        }
        return "Schedule saved."
    }

    private var alarmHelpText: String {
        if !draft.followsSystemTimeZone {
            return "iPhone alarms currently require Follow the system time zone."
        }

        return "Your iPhone confirms the alarm after it receives the iCloud schedule."
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

    @ViewBuilder
    private func serviceEditor(
        provider: ProviderID,
        title: String,
        detail: String,
        isOn: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: WakebarDesign.compactSpacing) {
            ProviderChoiceToggle(title: title, detail: detail, isOn: isOn)

            if isOn.wrappedValue {
                Divider()

                if !model.schedule.isEnabled
                    || !draft.hasSameHostedSetup(as: model.schedule, for: provider) {
                    Label("Save the schedule to continue setup.", systemImage: "clock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    HStack {
                        Label(
                            providerSetupStatus(for: provider),
                            systemImage: providerSetupStatusImage(for: provider)
                        )
                        .font(.footnote)
                        .foregroundStyle(providerSetupStatusColor(for: provider))

                        Spacer()

                        Button(model.isProviderReady(provider) ? "Manage…" : "Set Up…") {
                            providerSetupRequest = ProviderSetupRequest(
                                provider: provider,
                                purpose: .setup
                            )
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
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
        let shouldContinueSetup = !model.schedule.isEnabled || hasProviderAffectingDraftChanges
        let providerToSetUp = shouldContinueSetup ? firstProviderNeedingSetup : nil
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

    private func providerSetupStatus(for provider: ProviderID) -> String {
        guard model.isProviderReady(provider) else { return "Setup required" }
        return provider == .codex
            ? "Marked as set up by you · effect unverified"
            : "Marked as set up by you"
    }

    private func providerSetupStatusImage(for provider: ProviderID) -> String {
        guard model.isProviderReady(provider) else { return "circle.dashed" }
        return provider == .codex ? "flask.fill" : "checkmark.circle"
    }

    private func providerSetupStatusColor(for provider: ProviderID) -> Color {
        if !model.isProviderReady(provider) || provider == .codex {
            return .orange
        }
        return .secondary
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
