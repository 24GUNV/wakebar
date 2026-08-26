import SwiftUI
import WakebarCore

/// One service in the settings window, in the popover's grammar: what it is on
/// the left — led by its System Settings-style tile — what state it is in on
/// the right, and the switch that turns it on at the trailing edge where macOS
/// keeps its switches.
///
/// The status and the button only appear once the service is on. An off service
/// has no state worth reporting, and a row of greyed-out controls is noise.
struct ProviderSettingsRow: View {
    let title: String
    let tileSymbol: String
    let tileTint: Color
    var badge: String?
    let status: String
    let statusKind: ServiceStatusKind
    let actionTitle: String
    let isActionEnabled: Bool
    let actionHelp: String
    let action: () -> Void
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: WakebarDesign.compactSpacing) {
            SettingsIconTile(symbol: tileSymbol, tint: tileTint)

            Text(title)

            if let badge {
                RowBadge(text: badge)
            }

            Spacer(minLength: WakebarDesign.compactSpacing)

            if isOn {
                // The tooltip rides the pair rather than the button, because the
                // reason the button is dimmed has to stay reachable while it is.
                HStack(spacing: WakebarDesign.compactSpacing) {
                    WindowStatusValue(text: status, kind: statusKind)

                    Button(actionTitle, action: action)
                        .disabled(!isActionEnabled)
                }
                .help(actionHelp)
            }

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}
