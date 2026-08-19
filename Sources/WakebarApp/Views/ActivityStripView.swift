import SwiftUI

struct ActivityStripView: View {
    let message: String?

    var body: some View {
        Label(
            message ?? "Preview mode · provider connections are not configured",
            systemImage: message == nil ? "info.circle" : "checkmark.circle"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, WakebarDesign.horizontalPadding)
        .padding(.vertical, WakebarDesign.compactSpacing)
        .background(.quaternary)
    }
}
