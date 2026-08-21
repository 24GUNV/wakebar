import SwiftUI

/// Shown before a schedule exists at all. An empty state is the one place a
/// sentence earns its keep, so it gets exactly one.
struct DraftScheduleView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Schedule")
                .wakebarEyebrow()
                .padding(.bottom, 6)

            Text("Not set up")
                .font(WakebarDesign.hero)
                .foregroundStyle(.secondary)

            Text("Pick a wake time and the sessions that start with it.")
                .font(WakebarDesign.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wakebarInset()
        .padding(.vertical, WakebarDesign.sectionSpacing)
    }
}
