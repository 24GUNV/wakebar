import Foundation
import SwiftUI
import WakebarCore

struct ScheduleEditorView: View {
    @State private var draft: WakeSchedule
    @State private var wakeTime: Date
    let onCancel: () -> Void
    let onSave: (WakeSchedule) -> Void

    init(
        schedule: WakeSchedule,
        onCancel: @escaping () -> Void,
        onSave: @escaping (WakeSchedule) -> Void
    ) {
        _draft = State(initialValue: schedule)
        _wakeTime = State(initialValue: Self.date(for: schedule))
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.link)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Text("Wake schedule")
                    .font(.headline)

                Spacer()

                Button("Save and sync", action: save)
                    .buttonStyle(.link)
                    .disabled(!draft.isValid)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, WakebarDesign.horizontalPadding)
            .padding(.vertical, WakebarDesign.compactSpacing)

            Divider()

            VStack(spacing: 0) {
                LabeledContent("Wake time") {
                    DatePicker(
                        "Wake time",
                        selection: $wakeTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                }
                .padding(.vertical, WakebarDesign.compactSpacing)

                Divider()

                WeekdayPicker(selection: $draft.selectedWeekdays)
                    .padding(.vertical, WakebarDesign.compactSpacing)

                Divider()

                Picker("Start sessions", selection: $draft.sessionLeadMinutes) {
                    Text("5 min before").tag(5)
                    Text("10 min before").tag(10)
                    Text("15 min before").tag(15)
                    Text("30 min before").tag(30)
                }
                .pickerStyle(.menu)
                .padding(.vertical, WakebarDesign.compactSpacing)

                Divider()

                Toggle(isOn: $draft.alarmOnIPhone) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wake alarm on iPhone")
                        Text("Requires the companion app")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .padding(.vertical, WakebarDesign.compactSpacing)

                Divider()

                Toggle(isOn: $draft.repeatEveryFiveHours) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Refresh every five hours")
                        Text("Sends the same minimal prompt in a fresh session")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .padding(.vertical, WakebarDesign.compactSpacing)

                if draft.repeatEveryFiveHours {
                    Picker("Stop after", selection: $draft.repeatUntilHour) {
                        ForEach(12..<24, id: \.self) { hour in
                            Text(Self.hourLabel(hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.bottom, WakebarDesign.compactSpacing)
                }

                Divider()

                Text("Providers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, WakebarDesign.sectionSpacing)

                ProviderSelectionRow(
                    provider: .claude,
                    detail: "Cloud Routine · setup required · “hi”",
                    isSelected: $draft.includeClaude
                )

                ProviderSelectionRow(
                    provider: .codex,
                    detail: "\(draft.codexRoute.displayName) · setup required · “hi”",
                    isSelected: $draft.includeCodex
                )

                if !draft.isValid {
                    Label("Choose at least one day and provider.", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, WakebarDesign.compactSpacing)
                }
            }
            .padding(.horizontal, WakebarDesign.horizontalPadding)
            .padding(.bottom, WakebarDesign.sectionSpacing)
        }
    }

    private func save() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = draft.timeZone
        let components = calendar.dateComponents([.hour, .minute], from: wakeTime)
        draft.hour = components.hour ?? draft.hour
        draft.minute = components.minute ?? draft.minute
        onSave(draft)
    }

    private static func date(for schedule: WakeSchedule) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = schedule.timeZone
        return calendar.date(
            bySettingHour: schedule.hour,
            minute: schedule.minute,
            second: 0,
            of: .now
        ) ?? .now
    }

    private static func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(.dateTime.hour())
    }
}
