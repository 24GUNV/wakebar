import SwiftUI
import WakebarCore

struct WakeSummaryView: View {
    @Bindable var model: AppModel
    let onEdit: () -> Void
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            WakebarHeaderView(
                isEnabled: $model.schedule.isEnabled,
                onEdit: onEdit
            )

            Divider()
                .padding(.leading, WakebarDesign.horizontalPadding)

            NextWakeView(nextWake: model.nextWake)

            Divider()
                .padding(.leading, WakebarDesign.horizontalPadding)

            VStack(spacing: 0) {
                ScheduleEventRow(
                    date: model.nextSessionStart,
                    title: "Start \(model.selectedProviderSummary)",
                    detail: "Cloud schedule · sends “hi”",
                    systemImage: "sparkles",
                    readiness: .setupRequired
                )

                if model.schedule.alarmOnIPhone {
                    ScheduleEventRow(
                        date: model.nextWake,
                        title: "Sound alarm on iPhone",
                        detail: "Companion app not connected",
                        systemImage: "alarm",
                        readiness: .setupRequired
                    )
                }

                Toggle(isOn: $model.schedule.repeatEveryFiveHours) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("During the day")
                        Text("Repeat every five hours until 7 PM")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .padding(.vertical, WakebarDesign.compactSpacing)
                .accessibilityHint("Starts another minimal provider session every five hours")
            }
            .padding(.horizontal, WakebarDesign.horizontalPadding)

            ActivityStripView(message: model.activityMessage)

            Divider()

            HStack(spacing: WakebarDesign.compactSpacing) {
                Button(
                    model.hasSkippedNextWake ? "Restore next" : "Skip next",
                    action: model.toggleSkipNextWake
                )

                Spacer()

                Button("Settings", systemImage: "gearshape", action: showSettings)
                    .labelStyle(.iconOnly)

                Button("Test session start", systemImage: "play.fill", action: testSessionStart)
                    .disabled(model.isRunning)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, WakebarDesign.horizontalPadding)
            .padding(.vertical, WakebarDesign.compactSpacing)
        }
    }

    private func showSettings() {
        openSettings()
    }

    private func testSessionStart() {
        Task {
            await model.runNow()
        }
    }
}
