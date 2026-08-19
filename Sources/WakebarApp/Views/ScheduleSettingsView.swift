import SwiftUI
import WakebarCore

struct ScheduleSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            LaunchAtLoginSectionView(model: model)

            Section("Schedule") {
                if !model.schedule.isEnabled {
                    Button("Save and sync schedule") {
                        model.saveSchedule(model.schedule)
                    }
                    Text("Nothing is published until you save this draft.")
                        .foregroundStyle(.secondary)
                }

                Picker("Hour", selection: $model.schedule.hour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text(hour, format: .number.precision(.integerLength(2))).tag(hour)
                    }
                }

                Picker("Minute", selection: $model.schedule.minute) {
                    ForEach(0..<60, id: \.self) { minute in
                        Text(minute, format: .number.precision(.integerLength(2))).tag(minute)
                    }
                }

                LabeledContent("Repeat days") {
                    WeekdayPicker(selection: $model.schedule.selectedWeekdays)
                        .frame(maxWidth: 260)
                }

                Picker("Start sessions", selection: $model.schedule.sessionLeadMinutes) {
                    Text("5 minutes before").tag(5)
                    Text("10 minutes before").tag(10)
                    Text("15 minutes before").tag(15)
                    Text("30 minutes before").tag(30)
                }

                Toggle("Follow the system time zone", isOn: $model.schedule.followsSystemTimeZone)

                if !model.schedule.followsSystemTimeZone {
                    Picker("Time zone", selection: $model.schedule.timeZoneIdentifier) {
                        ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { identifier in
                            Text(identifier.replacing("_", with: " ")).tag(identifier)
                        }
                    }
                }

                LabeledContent("Next wake") {
                    if let nextWake = model.nextWake {
                        Text(nextWake, format: .dateTime.weekday(.wide).month().day().hour().minute())
                            .environment(\.timeZone, model.schedule.timeZone)
                    } else {
                        Text("Not scheduled")
                    }
                }
            }

            Section("Alarm") {
                Toggle("Sound an alarm on iPhone", isOn: $model.schedule.alarmOnIPhone)
                    .disabled(
                        !model.schedule.followsSystemTimeZone && !model.schedule.alarmOnIPhone
                    )
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
            }

            Section("Providers") {
                Toggle("Claude Code", isOn: $model.schedule.includeClaude)
                Toggle("Codex", isOn: $model.schedule.includeCodex)

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
            }

            Section("Session refresh") {
                Toggle("Repeat every five hours", isOn: $model.schedule.repeatEveryFiveHours)

                if model.schedule.repeatEveryFiveHours {
                    Picker("Stop after", selection: $model.schedule.repeatUntilHour) {
                        ForEach(12..<24, id: \.self) { hour in
                            Text(hour, format: .number).tag(hour)
                        }
                    }
                }
            }

            Section("Execution") {
                if model.schedule.includeClaude {
                    LabeledContent("Claude Code", value: "Cloud Routine")
                }

                if model.schedule.includeCodex {
                    LabeledContent("Codex", value: "ChatGPT scheduled task")
                }

                ForEach(model.executionSummaries, id: \.self) { summary in
                    Text(summary)
                        .foregroundStyle(.secondary)
                }

                Text("Create these cloud tasks in each provider, then confirm the saved times in Wakebar.")
                    .foregroundStyle(.secondary)
            }

            ProviderSetupSectionView(model: model)

            if let activityNotice = model.activityNotice {
                Section {
                    Text(activityNotice.message)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 520)
        .task {
            await model.load()
        }
    }

    private var alarmHelpText: String {
        if !model.schedule.followsSystemTimeZone {
            return "iPhone alarms currently require Follow the system time zone."
        }

        return "The iPhone confirms the alarm after it receives and applies the iCloud schedule."
    }
}
