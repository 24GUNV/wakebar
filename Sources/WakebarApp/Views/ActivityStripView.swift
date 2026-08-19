import SwiftUI

struct ActivityStripView: View {
    let notice: ActivityNotice

    var body: some View {
        Label(notice.message, systemImage: systemImage)
        .font(.footnote)
        .foregroundStyle(foregroundStyle)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, WakebarDesign.horizontalPadding)
        .padding(.vertical, WakebarDesign.compactSpacing)
        .background(.quaternary)
    }

    private var systemImage: String {
        switch notice.kind {
        case .information:
            "info.circle"
        case .success:
            "checkmark.circle"
        case .warning:
            "exclamationmark.triangle"
        case .error:
            "exclamationmark.circle"
        }
    }

    private var foregroundStyle: Color {
        switch notice.kind {
        case .information, .success:
            .secondary
        case .warning:
            .orange
        case .error:
            .red
        }
    }
}
