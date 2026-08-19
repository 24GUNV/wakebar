import SwiftUI

struct NextWakeView: View {
    let nextWake: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let nextWake {
                Text(nextWake, format: .dateTime.weekday(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(nextWake, format: .dateTime.hour().minute())
                    .font(.largeTitle)
                    .monospacedDigit()
            } else {
                Text("No wake scheduled")
                    .font(.title2)
                Text("Choose at least one day and provider.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, WakebarDesign.horizontalPadding)
        .padding(.vertical, WakebarDesign.sectionSpacing)
    }
}
