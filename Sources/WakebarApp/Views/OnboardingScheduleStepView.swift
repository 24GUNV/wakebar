import SwiftUI
import WakebarCore

/// Only the choices that shape provider setup appear here. Everything else
/// stays in the settings window.
struct OnboardingScheduleStepView: View {
    @Binding var draft: WakeSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: WakebarDesign.sectionSpacing) {
            OnboardingStepHeader(
                title: "Choose your wake time",
                detail: "Sessions start \(draft.sessionLeadMinutes) minutes earlier so the usage window is open when you wake.",
                systemImage: "clock"
            )

            HStack(alignment: .top, spacing: WakebarDesign.sectionSpacing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wake time")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    DatePicker(
                        "Wake time",
                        selection: wakeTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .controlSize(.large)
                    .font(.title2)
                    .monospacedDigit()
                    .environment(\.timeZone, draft.timeZone)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Next wake")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let nextWake {
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

            Text("Repeat")
                .font(.footnote)
                .foregroundStyle(.secondary)

            WeekdayPicker(selection: $draft.selectedWeekdays)

            if draft.selectedWeekdays.isEmpty {
                Label("Choose at least one day.", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Divider()

            Text("Services")
                .font(.footnote)
                .foregroundStyle(.secondary)

            serviceToggle(
                title: "Claude Code",
                detail: "Cloud Routine · works while this Mac is off",
                isOn: $draft.includeClaude
            )

            serviceToggle(
                title: "Codex",
                detail: "ChatGPT scheduled task · you create it once from exact instructions",
                isOn: $draft.includeCodex
            )

            if draft.providerIDs.isEmpty {
                Label("Choose at least one service.", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func serviceToggle(
        title: String,
        detail: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    /// The picker edits a `Date`; the draft keeps the hour and minute.
    private var wakeTime: Binding<Date> {
        Binding(
            get: { draft.wakeTimeOfDay },
            set: { draft.applyWakeTime($0) }
        )
    }

    private var nextWake: Date? {
        guard draft.isValid else { return nil }
        var activeDraft = draft
        activeDraft.isEnabled = true
        return ScheduleCalculator().nextWakeOccurrence(after: .now, for: activeDraft)
    }
}
