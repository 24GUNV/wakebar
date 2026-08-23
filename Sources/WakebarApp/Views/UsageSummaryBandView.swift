import SwiftUI
import WakebarCore

struct UsageSummaryBandView: View {
    let summary: UsageSummaryViewModel
    let startStates: [ProviderID: ProviderStartNowState]
    let onStartNow: (ProviderID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WakebarDesign.compactSpacing) {
            Text(summary.nextWindowText)
                .font(WakebarDesign.rowTitle)
                .monospacedDigit()
                .foregroundStyle(.primary)

            ForEach(summary.providers) { provider in
                UsageProviderView(
                    presentation: provider,
                    startState: startStates[provider.provider] ?? .idle,
                    onStartNow: { onStartNow(provider.provider) }
                )
            }
        }
        .wakebarInset()
        .padding(.vertical, WakebarDesign.bandPadding)
    }
}
