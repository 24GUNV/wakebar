import SwiftUI

struct UsageWindowBarView: View {
    let bar: UsageWindowBarModel

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: WakebarDesign.compactSpacing) {
                Text(bar.label)
                Spacer(minLength: WakebarDesign.compactSpacing)
                Text("\(bar.usedText) · \(bar.resetText)")
                    .monospacedDigit()
            }
            .font(WakebarDesign.detail)
            .foregroundStyle(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.18))

                    Capsule()
                        .fill(.tint)
                        .frame(width: geometry.size.width * (bar.usedFraction ?? 0))
                }
            }
            .frame(height: WakebarDesign.progressBarHeight)
            .accessibilityElement()
            .accessibilityLabel("\(bar.provider.displayName) \(bar.label) usage")
            .accessibilityValue("\(bar.usedText), \(bar.resetText)")
        }
    }
}
