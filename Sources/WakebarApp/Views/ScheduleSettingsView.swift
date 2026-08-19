import SwiftUI
import WakebarCore

struct ScheduleSettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Schedule") {
                Toggle("Schedule enabled", isOn: $model.schedule.isEnabled)

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
                Text("An iPhone companion app will be required before this can alert.")
                    .foregroundStyle(.secondary)
            }

            Section("Providers") {
                Toggle("Claude Code", isOn: $model.schedule.includeClaude)
                Toggle("Codex", isOn: $model.schedule.includeCodex)
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
                    Picker("Claude Code", selection: $model.schedule.claudeBackend) {
                        ForEach(model.supportedBackends(for: .claude)) { backend in
                            Text(backend.displayName).tag(backend)
                        }
                    }
                }

                if model.schedule.includeCodex {
                    Picker("Codex", selection: $model.schedule.codexBackend) {
                        ForEach(model.supportedBackends(for: .codex)) { backend in
                            Text(backend.displayName).tag(backend)
                        }
                    }
                }

                ForEach(model.executionSummaries, id: \.self) { summary in
                    Text(summary)
                        .foregroundStyle(.secondary)
                }

                Text("Provider actions remain in preview mode in this build.")
                    .foregroundStyle(.secondary)
            }

            if let activityMessage = model.activityMessage {
                Section {
                    Text(activityMessage)
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
}
