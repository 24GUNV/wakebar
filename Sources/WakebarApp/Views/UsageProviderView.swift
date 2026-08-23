import SwiftUI

struct UsageProviderView: View {
    let presentation: UsageProviderPresentation
    let startState: ProviderStartNowState
    let onStartNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: WakebarDesign.compactSpacing) {
                Text(presentation.provider.displayName)
                    .font(WakebarDesign.rowTitle)

                Spacer(minLength: WakebarDesign.compactSpacing)

                Button("Start now", action: onStartNow)
                    .buttonStyle(.borderless)
                    .font(WakebarDesign.rowValue)
                    .disabled(startState == .requested)
            }

            if let statusText {
                Text(statusText)
                    .font(WakebarDesign.detail)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ForEach(presentation.bars) { bar in
                UsageWindowBarView(bar: bar)
            }

            if let issueMessage = presentation.issueMessage {
                Text(issueMessage)
                    .font(WakebarDesign.detail)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var statusText: String? {
        switch startState {
        case .idle:
            nil
        case .requested:
            "Requested"
        case let .started(date):
            "Window started \(date.formatted(.dateTime.hour().minute()))"
        case .unconfirmed:
            "Requested; not confirmed"
        }
    }
}
