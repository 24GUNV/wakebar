import SwiftUI
import UIKit

struct PhoneAlarmPermissionSection: View {
    @Environment(\.openURL) private var openURL

    let model: PhoneCompanionModel

    var body: some View {
        if model.status == .permissionRequired {
            Section {
                Button("Allow and set alarm", systemImage: "bell.badge", action: allowAlarm)
                    .frame(minHeight: PhoneDesign.minimumTapTarget)
                    .disabled(model.isBusy)
            } footer: {
                Text("iOS asks once. You can change access later in Settings.")
            }
        } else if model.status == .readyToSet {
            Section {
                Button("Set alarm", systemImage: "alarm", action: allowAlarm)
                    .frame(minHeight: PhoneDesign.minimumTapTarget)
                    .disabled(model.isBusy)
            } footer: {
                Text("Alarm access is already on. Wakebar will set this synced schedule.")
            }
        } else if model.status == .permissionDenied {
            Section {
                Button("Open Settings", systemImage: "gear", action: openSettings)
                    .frame(minHeight: PhoneDesign.minimumTapTarget)
            } footer: {
                Text("Turn on alarm access for Wakebar, then return to this screen.")
            }
        } else if model.status == .alarmMissing {
            Section {
                Button("Set alarm again", systemImage: "alarm", action: allowAlarm)
                    .frame(minHeight: PhoneDesign.minimumTapTarget)
                    .disabled(model.isBusy)
            } footer: {
                Text("Wakebar will register the current schedule again.")
            }
        } else if model.status.isFailure {
            Section {
                Button("Try again", systemImage: "arrow.clockwise", action: retry)
                    .frame(minHeight: PhoneDesign.minimumTapTarget)
                    .disabled(model.isBusy)
            } footer: {
                Text("Wakebar will refresh iCloud and reconcile its managed alarms.")
            }
        }
    }

    private func allowAlarm() {
        Task {
            await model.allowAndSetAlarm()
        }
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }

    private func retry() {
        Task {
            await model.refresh()
        }
    }
}

private extension PhoneCompanionStatus {
    var isFailure: Bool {
        if case .failed = self { true } else { false }
    }
}
