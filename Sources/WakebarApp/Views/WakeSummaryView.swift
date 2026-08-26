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
                    nextFireProvider: model.nextFireProvider,
                    wakeTimeText: model.wakeTimeText,
                    weekdaySummary: model.weekdaySummary,
                    isActive: $model.isScheduleActive,
                    onCadenceChange: { model.sessionCadence = $0 }
                )

                insetDivider

                if model.isScheduleActive {
                    serviceRows
                } else {
                    stoppedRows
                }

                insetDivider

                TimelineView(.periodic(from: .now, by: 60)) { context in
                    UsageSummaryBandView(
                        summary: model.usageSummary(at: context.date),
                        startStates: model.providerStartNowStates,
                        onStartNow: model.startNow
                    )
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
                    badge: nil,
                    action: { showSettings(.providers) }
                )
            }

        }
    }

    /// ChatGPT tasks are user-managed, so switching Wakebar off cannot disable
    /// them. The row keeps that external state visible.
    private var stoppedRows: some View {
        rowBand {
            if model.hasHostedSessions {
                ServiceStatusRow(
                    title: "ChatGPT task",
                    status: "Still scheduled",
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
                // An unsaved schedule has nothing to edit yet, so the primary
                // action runs the guided setup instead.
                if model.scheduleMenuState == .draft, !model.hasSchedule {
                    showSetupGuide()
                } else {
                    showSettings(model.relevantSettingsDestination)
                }
            }

            Spacer(minLength: WakebarDesign.compactSpacing)

            Menu {
                Button("Settings…") { showSettings(.general) }
                    .keyboardShortcut(",", modifiers: .command)

                Button("Setup Guide…", action: showSetupGuide)

                Button("Preview setup", action: testSessionStart)
                    .disabled(model.isRunning)

                Divider()

                Link("Check for updates", destination: WakebarRelease.releasesURL)

                Text("Wakebar \(WakebarRelease.currentVersion)")

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

    private func showSetupGuide() {
        model.beginOnboarding()
        NSApplication.shared.activate()
        openWindow(id: "onboarding")
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
