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

                Spacer()

                Text("Wake schedule")
                    .font(.headline)

                Spacer()

                Button("Done", action: save)
                    .buttonStyle(.link)
                    .disabled(!draft.isValid)
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

                Toggle("Alarm on iPhone", isOn: $draft.alarmOnIPhone)
                    .toggleStyle(.switch)
                    .padding(.vertical, WakebarDesign.compactSpacing)

                Divider()

                Toggle("Repeat sessions every 5 hours", isOn: $draft.repeatEveryFiveHours)
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
                    detail: "Fresh temporary chat · “hi”",
                    isSelected: $draft.includeClaude
                )

                ProviderSelectionRow(
                    provider: .codex,
                    detail: "Fresh scheduled task · “hi”",
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
        let components = Calendar.current.dateComponents([.hour, .minute], from: wakeTime)
        draft.hour = components.hour ?? draft.hour
        draft.minute = components.minute ?? draft.minute
        draft.skippedWakeDate = nil
        onSave(draft)
    }

    private static func date(for schedule: WakeSchedule) -> Date {
        Calendar.current.date(
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
