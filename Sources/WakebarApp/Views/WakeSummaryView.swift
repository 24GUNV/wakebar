import SwiftUI
import WakebarCore

struct WakeSummaryView: View {
    @Bindable var model: AppModel
    let onEdit: () -> Void
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            WakebarHeaderView(
                status: model.scheduleStatusText,
                onEdit: onEdit
            )

            Divider()
                .padding(.leading, WakebarDesign.horizontalPadding)

            if model.schedule.isEnabled {
                NextWakeView(nextWake: model.nextWake)

                Divider()
                    .padding(.leading, WakebarDesign.horizontalPadding)

                VStack(spacing: 0) {
                    if let nextInitialSessionStart = model.nextInitialSessionStart {
                        ScheduleEventRow(
                            date: nextInitialSessionStart,
                            title: "Start \(model.selectedProviderSummary)",
                            detail: model.sessionExecutionDetail,
                            systemImage: "sparkles",
                            readiness: model.providerReadiness
                        )
                    }

                    if let nextPhoneAlarm = model.nextPlannedPhoneAlarm {
                        ScheduleEventRow(
                            date: nextPhoneAlarm,
                            title: "Wake alarm",
                            detail: model.phoneAlarmDetail,
                            systemImage: "alarm",
                            readiness: model.phoneAlarmReadiness
                        )
                    }

                    if !model.refreshSessionDates.isEmpty {
                        ScheduleEventRow(
                            date: model.refreshSessionDates.first,
                            title: "Session refreshes",
                            detail: refreshDetail,
                            systemImage: "arrow.clockwise",
                            readiness: model.providerReadiness
                        )
                    }
                }
                .padding(.horizontal, WakebarDesign.horizontalPadding)
            } else {
                DraftScheduleView(
                    phoneStatus: model.draftPhoneStatus,
                    onFinishSetup: onEdit
                )
            }

            if let activityNotice = model.activityNotice {
                ActivityStripView(notice: activityNotice)
            }

            Divider()

            HStack(spacing: WakebarDesign.compactSpacing) {
                Spacer()

                Button("Settings", systemImage: "gearshape", action: showSettings)
                    .labelStyle(.iconOnly)

                Button("Quit Wakebar", systemImage: "power", action: quitWakebar)
                    .labelStyle(.iconOnly)

                Button("Preview", systemImage: "play.fill", action: testSessionStart)
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

    private func quitWakebar() {
        NSApplication.shared.terminate(nil)
    }

    private var refreshDetail: String {
        guard model.schedule.repeatEveryFiveHours else {
            return "Off"
        }

        let count = model.refreshSessionDates.count
        if count > 0 {
            return count == 1 ? "1 refresh planned" : "\(count) refreshes planned"
        }

        return "No additional refreshes before the cutoff"
    }
}
