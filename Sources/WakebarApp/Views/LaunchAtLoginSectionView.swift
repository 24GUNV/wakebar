import SwiftUI

struct LaunchAtLoginSectionView: View {
    @Bindable var model: AppModel

    var body: some View {
        Section("General") {
            LabeledContent("Launch at login") {
                Text(model.launchAtLoginState.displayName)
                    .foregroundStyle(.secondary)
            }

            switch model.launchAtLoginState {
            case .off:
                Button("Enable launch at login", action: model.enableLaunchAtLogin)
            case .on:
                Button("Disable launch at login", action: model.disableLaunchAtLogin)
            case .requiresApproval:
                Button("Open Login Items", action: model.openLoginItemSettings)
                Text("Allow Wakebar in System Settings, then reopen the app.")
                    .foregroundStyle(.secondary)
            case .unavailable:
                Text("Launch at login requires an installed Wakebar app.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
