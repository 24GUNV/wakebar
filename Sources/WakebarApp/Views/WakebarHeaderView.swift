import SwiftUI

struct WakebarHeaderView: View {
    @Binding var isEnabled: Bool
    let status: String
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Text("Wakebar")
                .font(.headline)

            Spacer()

            Text(status)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("Wake schedule", isOn: $isEnabled)
                .labelsHidden()

            Button("Edit schedule", action: onEdit)
                .buttonStyle(.link)
        }
        .padding(.horizontal, WakebarDesign.horizontalPadding)
        .padding(.vertical, WakebarDesign.compactSpacing)
    }
}
