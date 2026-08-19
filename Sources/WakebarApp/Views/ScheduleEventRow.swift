import SwiftUI

struct ScheduleEventRow: View {
    let date: Date?
    let title: String
    let detail: String
    let systemImage: String
    let readiness: ScheduleEventReadiness

    var body: some View {
        HStack(spacing: WakebarDesign.compactSpacing) {
            Group {
                if let date {
                    Text(date, format: .dateTime.hour().minute())
                } else {
                    Text("—")
                }
            }
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: 58, alignment: .leading)

            Image(systemName: systemImage)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(2)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: readiness == .ready ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(readiness == .ready ? .green : .secondary)
                .accessibilityLabel(readiness == .ready ? "Ready" : "Setup required")
        }
        .frame(minHeight: WakebarDesign.eventRowHeight)
        .accessibilityElement(children: .combine)
    }
}
