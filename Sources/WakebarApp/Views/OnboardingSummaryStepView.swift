import SwiftUI
import WakebarCore

struct OnboardingSummaryStepView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: WakebarDesign.sectionSpacing) {
            OnboardingStepHeader(
                title: headerTitle,
                detail: headerDetail,
                systemImage: model.providerReadiness == .ready ? "checkmark.circle" : "circle.dashed"
            )

            LabeledContent("Next wake") {
                if let nextWake = model.nextWake {
                    Text(
                        nextWake,
                        format: .dateTime
                            .weekday(.abbreviated)
                            .month(.abbreviated)
                            .day()
                            .hour()
                            .minute()
                    )
                    .monospacedDigit()
                } else {
                    Text("Not scheduled")
                        .foregroundStyle(.secondary)
                }
            }
            .environment(\.timeZone, model.schedule.timeZone)

            Divider()

            ForEach(model.schedule.providerIDs) { provider in
                ServiceStatusRow(
                    title: provider.displayName,
                    status: model.providerMenuStatus(for: provider),
                    kind: model.providerMenuStatusKind(for: provider)
                )
            }

            Text("Wakebar stays in the menu bar. Open it any time to check status, edit the schedule, or run this guide again.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var headerTitle: String {
        model.providerReadiness == .ready ? "You're set up" : "Almost there"
    }

    private var headerDetail: String {
        model.providerReadiness == .ready
            ? "Wakebar will start the sessions you confirmed. It does not receive independent proof that a provider reset a usage window."
            : "One service still needs its provider task. Reopen this guide, or finish setup from the menu, whenever you are ready."
    }
}
