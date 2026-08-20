import SwiftUI

struct RefreshSummaryView: View {
    let nextRefresh: Date?

    var body: some View {
        Group {
            if let nextRefresh {
                HStack(spacing: 3) {
                    Text("Every 5 hours · next")
                    Text(nextRefresh, format: .dateTime.hour().minute())
                        .monospacedDigit()
                }
            } else {
                Text("No additional refreshes before cutoff")
            }
        }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, WakebarDesign.horizontalPadding)
            .padding(.vertical, WakebarDesign.compactSpacing)
            .accessibilityElement(children: .combine)
    }
}
