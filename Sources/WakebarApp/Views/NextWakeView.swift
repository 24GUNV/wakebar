import SwiftUI

struct NextWakeView: View {
    let nextWake: Date?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Next wake")
                .foregroundStyle(.secondary)

            Spacer()

            if let nextWake {
                Text(nextWake, format: .dateTime.weekday(.wide).hour().minute())
                    .font(.headline)
                    .monospacedDigit()
            } else {
                Text("Not scheduled")
                    .font(.headline)
            }
        }
        .padding(.horizontal, WakebarDesign.horizontalPadding)
        .padding(.vertical, WakebarDesign.compactSpacing)
        .accessibilityElement(children: .combine)
    }
}
