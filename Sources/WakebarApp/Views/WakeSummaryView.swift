import SwiftUI
import WakebarCore

struct WakeSummaryView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            if model.hasSchedule {
                WakeCountdownView(
                    nextFire: model.nextFire,
                    cadence: model.sessionCadence,
                    wakeTimeText: model.wakeTimeText,
                    weekdaySummary: model.weekdaySummary,
                    isActive: $model.isScheduleActive,
                    onCadenceChange: { model.sessionCadence = $0 }
                )

                insetDivider

                if model.isScheduleActive {
                    serviceRows

                    if model.showsUsageBand {
                        insetDivider
                        RefreshSummaryView(
                            nextRefresh: model.refreshSessionDates.first,
                            windows: model.usageWindowRows,
                            assumedCadenceHour: model.assumedCadenceHour,
                            showsNextSession: model.sessionCadence == .schedule
                        )
                    }
                } else {
                    stoppedRows
                }
            } else {
                DraftScheduleView()
            }

            if let activityNotice = model.activityNotice {
                ActivityStripView(notice: activityNotice)
            }

            Divider()

            footer
        }
    }

    // MARK: - Bands

    private var serviceRows: some View {
        rowBand {
            ForEach(model.schedule.providerIDs) { provider in
                ServiceStatusRow(
                    title: provider.displayName,
                    status: model.providerMenuStatus(for: provider),
                    kind: model.providerMenuStatusKind(for: provider),
                    badge: model.providerIsExperimental(provider) ? "Experimental" : nil,
                    action: { showSettings(.providers) }
                )
            }

            if model.schedule.alarmOnIPhone {
                ServiceStatusRow(
                    title: "iPhone alarm",
                    status: model.phoneAlarmMenuStatus,
                    kind: model.phoneAlarmServiceStatusKind,
                    action: { showSettings(.alarm) }
                )
            }
        }
    }

    /// Switching Wakebar off stops its own alarm but cannot reach a Routine
    /// already living in a provider's cloud. Saying so as two rows keeps the
    /// caveat scannable instead of turning the popover into a paragraph.
    private var stoppedRows: some View {
        rowBand {
            if model.schedule.alarmOnIPhone {
                ServiceStatusRow(
                    title: "iPhone alarm",
                    status: model.stoppedPhoneStatus,
                    kind: model.stoppedPhoneStatusKind,
                    action: { showSettings(.alarm) }
                )
            }

            if model.hasHostedSessions {
                ServiceStatusRow(
                    title: "Cloud sessions",
                    status: "Still running",
                    kind: .inProgress,
                    action: { showSettings(.providers) }
                )
            }
        }
    }

    private func rowBand<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, WakebarDesign.horizontalPadding - WakebarDesign.compactSpacing)
        .padding(.vertical, 4)
    }

    private var footer: some View {
        HStack(spacing: 2) {
            Button(model.primaryMenuActionTitle) {
                showSettings(model.relevantSettingsDestination)
            }

            Spacer(minLength: WakebarDesign.compactSpacing)

            Menu {
                Button("Settings…") { showSettings(.general) }
                    .keyboardShortcut(",", modifiers: .command)

                Button("Preview setup", action: testSessionStart)
                    .disabled(model.isRunning)

                Divider()

                Button("Quit Wakebar", action: quitWakebar)
                    .keyboardShortcut("q", modifiers: .command)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 24, height: 20)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More")
        }
        .buttonStyle(PopoverFooterButtonStyle())
        .padding(.horizontal, WakebarDesign.horizontalPadding - WakebarDesign.compactSpacing)
        .padding(.vertical, 5)
    }

    private var insetDivider: some View {
        Divider()
            .padding(.leading, WakebarDesign.horizontalPadding)
    }

    // MARK: - Actions

    private func showSettings(_ destination: SettingsDestination) {
        model.requestSettings(destination)
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
}
