import SwiftUI

struct OnboardingWelcomeStepView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: WakebarDesign.sectionSpacing) {
            OnboardingStepHeader(
                title: "Welcome to Wakebar",
                detail: "Wakebar starts your Claude Code and Codex usage windows before you wake up, so the first session of the day is already warm.",
                systemImage: "alarm"
            )

            pointer(
                systemImage: "clock",
                title: "One wake time",
                detail: "Pick when you wake and which days repeat. Wakebar works backwards to the session start."
            )

            pointer(
                systemImage: "cloud",
                title: "Provider-hosted tasks",
                detail: "Claude Code Routines and ChatGPT scheduled tasks run in the cloud, so this Mac can be off."
            )

            pointer(
                systemImage: "hand.raised",
                title: "You stay in control",
                detail: "Wakebar prepares the setup details; you review and save each task with the provider."
            )
        }
    }

    private func pointer(systemImage: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: WakebarDesign.sectionSpacing) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
