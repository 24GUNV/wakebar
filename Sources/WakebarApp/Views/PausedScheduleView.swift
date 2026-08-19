import SwiftUI

struct DraftScheduleView: View {
    let phoneStatus: String?
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

            if let phoneStatus {
                Label(phoneStatus, systemImage: "iphone.and.arrow.forward")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, WakebarDesign.horizontalPadding)
            }
        }
        .padding(.vertical, WakebarDesign.sectionSpacing)
    }
}
