import SwiftUI
import WakebarCore

struct WakeSummaryView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            if model.schedule.isEnabled {
                WakeOverviewHeaderView(
                    nextWake: model.nextWake,
                    nextSessionStart: model.nextInitialSessionStart,
                    status: model.scheduleStatusText,
                    menuState: model.scheduleMenuState
                )

                Divider()
                    .padding(.leading, WakebarDesign.horizontalPadding)

                VStack(spacing: 0) {
                    ForEach(model.schedule.providerIDs) { provider in
                        ServiceStatusRow(
                            title: provider.displayName,
                            status: model.providerMenuStatus(for: provider),
                            kind: model.providerMenuStatusKind(for: provider)
                        )
                    }

                    if model.schedule.alarmOnIPhone {
                        ServiceStatusRow(
                            title: "iPhone alarm",
                            status: model.phoneAlarmMenuStatus,
                            kind: model.phoneAlarmServiceStatusKind
                        )
                    }
                }
                .padding(.horizontal, WakebarDesign.horizontalPadding)

                if model.schedule.repeatEveryFiveHours {
                    Divider()
                        .padding(.leading, WakebarDesign.horizontalPadding)

                    RefreshSummaryView(nextRefresh: model.refreshSessionDates.first)
                }
            } else {
                DraftScheduleView(phoneStatus: model.draftPhoneStatus)
            }

            if let activityNotice = model.activityNotice {
                ActivityStripView(notice: activityNotice)
            }

            Divider()

            HStack(spacing: WakebarDesign.compactSpacing) {
                Button(primaryActionTitle, systemImage: "calendar", action: showRelevantSettings)

                Spacer(minLength: WakebarDesign.sectionSpacing)

                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Settings…", systemImage: "gearshape", action: showGeneralSettings)
                        .keyboardShortcut(",", modifiers: .command)

                    Button("Preview setup", systemImage: "play", action: testSessionStart)
                        .disabled(model.isRunning)

                    Divider()

                    Button("Quit Wakebar", systemImage: "power", action: quitWakebar)
                        .keyboardShortcut("q", modifiers: .command)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, WakebarDesign.horizontalPadding)
            .padding(.vertical, WakebarDesign.compactSpacing)
        }
    }

    private func showRelevantSettings() {
        model.requestSettings(model.relevantSettingsDestination)
        showSettingsWindow()
    }

    private func showGeneralSettings() {
        model.requestSettings(.general)
        showSettingsWindow()
    }

    private func showSettingsWindow() {
        NSApplication.shared.activate()
        openWindow(id: "settings")
    }

    private func testSessionStart() {
        Task {
            await model.runNow()
        }
    }

    private func quitWakebar() {
        NSApplication.shared.terminate(nil)
    }

    private var primaryActionTitle: String {
        model.primaryMenuActionTitle
    }
}
