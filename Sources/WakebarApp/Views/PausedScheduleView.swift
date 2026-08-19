import SwiftUI

struct DraftScheduleView: View {
    let onFinishSetup: () -> Void

    var body: some View {
        VStack(spacing: WakebarDesign.compactSpacing) {
            ContentUnavailableView(
                "Finish your schedule",
                systemImage: "alarm.waves.left.and.right",
                description: Text("Review the wake time, providers, and iPhone alarm before Wakebar syncs. Provider tasks stay managed in Claude and ChatGPT.")
            )

            Button("Finish setup", action: onFinishSetup)
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, WakebarDesign.sectionSpacing)
    }
}
