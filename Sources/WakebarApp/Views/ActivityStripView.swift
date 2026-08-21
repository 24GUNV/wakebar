import SwiftUI

/// A transient line about something Wakebar just did. It sits above the footer
/// so it never displaces the countdown.
struct ActivityStripView: View {
    let notice: ActivityNotice

    var body: some View {
        Text(notice.message)
            .font(WakebarDesign.detail)
            .foregroundStyle(foregroundStyle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .wakebarInset()
            .padding(.vertical, WakebarDesign.compactSpacing)
            .background(.quaternary)
            .transition(.opacity)
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
