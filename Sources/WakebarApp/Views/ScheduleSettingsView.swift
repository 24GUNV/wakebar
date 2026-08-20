import AppKit
import SwiftUI
import WakebarCore

struct ScheduleSettingsView: View {
    @Bindable var model: AppModel
    @State private var draft: WakeSchedule

    init(model: AppModel) {
        self.model = model
        _draft = State(initialValue: model.schedule)
    }

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                LaunchAtLoginSectionView(model: model)
                    .id(SettingsDestination.general)

                Section("Schedule") {
                    Picker("Hour", selection: $draft.hour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(hour, format: .number.precision(.integerLength(2))).tag(hour)
                        }
                    }

                    Picker("Minute", selection: $draft.minute) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text(minute, format: .number.precision(.integerLength(2))).tag(minute)
                        }
                    }

                    LabeledContent("Repeat days") {
                        WeekdayPicker(selection: $draft.selectedWeekdays)
                            .frame(maxWidth: 260)
                    }

                    Picker("Start sessions", selection: $draft.sessionLeadMinutes) {
                        Text("5 minutes before").tag(5)
                        Text("10 minutes before").tag(10)
                        Text("15 minutes before").tag(15)
                        Text("30 minutes before").tag(30)
                    }

                    Toggle("Follow the system time zone", isOn: $draft.followsSystemTimeZone)

                    if !draft.followsSystemTimeZone {
                        Picker("Time zone", selection: $draft.timeZoneIdentifier) {
                            ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { identifier in
                                Text(identifier.replacing("_", with: " ")).tag(identifier)
                            }
                        }
                    }

                    LabeledContent("Next wake") {
                        if let nextWake = draftNextWake {
                            Text(nextWake, format: .dateTime.weekday(.wide).month().day().hour().minute())
                                .environment(\.timeZone, draft.timeZone)
                        } else {
                            Text("Choose a day and provider")
                        }
                    }

                    Button(model.schedule.isEnabled ? "Save changes" : "Save and sync schedule") {
                        saveDraft()
                    }
                    .disabled(!draft.isValid || (model.schedule.isEnabled && draft == model.schedule))

                    Text(saveHelpText)
                        .foregroundStyle(.secondary)
                }
                .id(SettingsDestination.schedule)

                Section("Alarm") {
                    Toggle("Sound an alarm on iPhone", isOn: $draft.alarmOnIPhone)
                        .disabled(!draft.followsSystemTimeZone && !draft.alarmOnIPhone)
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

                        Button("Retry Sync", systemImage: "arrow.clockwise") {
                            Task {
                                await model.retryPhoneSchedule()
                            }
                        }
                    }
                }
                .id(SettingsDestination.alarm)

                Section("Providers") {
                    Toggle("Claude Code", isOn: $draft.includeClaude)
                    Toggle("Codex", isOn: $draft.includeCodex)

                    ForEach(model.snapshots) { snapshot in
                        LabeledContent(snapshot.provider.displayName) {
                            let delivery = model.providerDeliveryStates[snapshot.provider]
                            Text(delivery?.phase.displayName ?? "Draft")
                                .foregroundStyle(.secondary)
                        }

                        if let configurationStatus = snapshot.availability.exceptionalMenuText {
                            Text(configurationStatus)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if draft.providerIDs.isEmpty {
                        Label("Choose at least one provider.", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                    }
                }

                Section("Session refresh") {
                    Toggle("Repeat every five hours", isOn: $draft.repeatEveryFiveHours)

                    if draft.repeatEveryFiveHours {
                        Picker("Stop after", selection: $draft.repeatUntilHour) {
                            ForEach(12..<24, id: \.self) { hour in
                                Text(hour, format: .number).tag(hour)
                            }
                        }
                    }
                }

                Section("Execution") {
                    if draft.includeClaude {
                        LabeledContent("Claude Code", value: "Cloud Routine")
                    }

                    if draft.includeCodex {
                        LabeledContent("Codex", value: "ChatGPT scheduled task")
                    }

                    Text("Create these cloud tasks in each provider, then confirm the saved times in Wakebar.")
                        .foregroundStyle(.secondary)
                }

                ProviderSetupSectionView(model: model)
                    .id(SettingsDestination.providers)

                if let activityNotice = model.activityNotice {
                    Section {
                        Text(activityNotice.message)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 520, minHeight: 560)
            .onAppear {
                NSApplication.shared.activate()
            }
            .task {
                await model.load()
                draft = model.schedule
                proxy.scrollTo(model.settingsDestination, anchor: .top)
            }
            .onChange(of: model.settingsDestination) { _, destination in
                proxy.scrollTo(destination, anchor: .top)
            }
            .onChange(of: model.schedule) { oldSchedule, newSchedule in
                if draft == oldSchedule {
                    draft = newSchedule
                }
            }
        }
    }

    private var draftNextWake: Date? {
        guard draft.isValid else { return nil }
        var activeDraft = draft
        activeDraft.isEnabled = true
        return ScheduleCalculator().nextWakeOccurrence(after: .now, for: activeDraft)
    }

    private var saveHelpText: String {
        if !model.schedule.isEnabled {
            return "Nothing is published until you save this draft."
        }
        if draft != model.schedule {
            return "Wakebar keeps the current phone alarm until you save and the iPhone confirms the update."
        }
        return "Provider tasks remain managed in Claude and ChatGPT."
    }

    private var alarmHelpText: String {
        if !draft.followsSystemTimeZone {
            return "iPhone alarms currently require Follow the system time zone."
        }

        return "The iPhone confirms the alarm after it receives and applies the iCloud schedule."
    }

    private func saveDraft() {
        model.saveSchedule(draft)
        draft = model.schedule
    }
}
