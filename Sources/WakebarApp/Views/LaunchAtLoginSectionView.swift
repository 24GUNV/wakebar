import SwiftUI

/// Launch at login as one row: the switch when Wakebar can set it itself, and
/// the way out to System Settings when it cannot.
///
/// The old row printed the state and then a button that said the same thing
/// again ("Off" / "Enable launch at login"). A switch is both.
struct LaunchAtLoginSectionView: View {
    @Bindable var model: AppModel

    var body: some View {
        LabeledContent("Launch at login") {
            switch model.launchAtLoginState {
            case .off, .on:
                Toggle("Launch at login", isOn: isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            case .requiresApproval:
                HStack(spacing: WakebarDesign.compactSpacing) {
                    WindowStatusValue(text: "Approval required", kind: .actionRequired)

                    Button("Open Login Items…", action: model.openLoginItemSettings)
                }
            case .unavailable:
                Text("Unavailable")
                    .foregroundStyle(.secondary)
            }
        }
        .help(helpText)
    }

    private var isEnabled: Binding<Bool> {
        Binding(
            get: { model.launchAtLoginState == .on },
            set: { shouldEnable in
                if shouldEnable {
                    model.enableLaunchAtLogin()
                } else {
                    model.disableLaunchAtLogin()
                }
            }
        )
    }

    /// The sentences this row used to print now live in its tooltip, which is
    /// where macOS keeps the detail a control cannot show.
    private var helpText: String {
        switch model.launchAtLoginState {
        case .off, .on:
            "Open Wakebar automatically when you log in."
        case .requiresApproval:
            "Approve Wakebar in Login Items, then reopen it."
        case .unavailable:
            "Launch at login needs Wakebar in your Applications folder."
        }
    }
}
