import SwiftUI
import WakebarCore

struct WakeSummaryView: View {
    @Bindable var model: AppModel

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
                            kind: model.isProviderReady(provider) ? .ready : .actionRequired
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
                SettingsLink {
                    Label(primaryActionTitle, systemImage: "calendar")
                }
                .simultaneousGesture(
                    TapGesture().onEnded { prepareRelevantSettings() }
                )

                Spacer(minLength: WakebarDesign.sectionSpacing)

                Menu("More", systemImage: "ellipsis.circle") {
                    SettingsLink {
                        Label("Settings…", systemImage: "gearshape")
                    }
                    .simultaneousGesture(
                        TapGesture().onEnded { prepareGeneralSettings() }
                    )
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

    private func prepareRelevantSettings() {
        model.settingsDestination = model.relevantSettingsDestination
    }

    private func prepareGeneralSettings() {
        model.settingsDestination = .general
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
