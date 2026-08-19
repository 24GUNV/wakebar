import SwiftUI
import WakebarCore

struct ProviderSelectionRow: View {
    let provider: ProviderID
    let detail: String
    @Binding var isSelected: Bool

    var body: some View {
        Toggle(isOn: $isSelected) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: provider.systemImage)
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, WakebarDesign.compactSpacing)
    }
}
