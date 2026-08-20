import SwiftUI
import WakebarCore

struct WakeOverviewHeaderView: View {
    let nextWake: Date?
    let nextSessionStart: Date?
    let status: String
    let menuState: ScheduleMenuState
    @Environment(\.timeZone) private var timeZone

    var body: some View {
        HStack(alignment: .top, spacing: WakebarDesign.sectionSpacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let nextWake {
                    Text(nextWake, format: .dateTime.hour().minute())
                        .font(.title2)
                        .bold()
                        .monospacedDigit()
                } else {
                    Text("Not scheduled")
                        .font(.title2)
                        .bold()
                }

                if let nextSessionStart {
                    HStack(spacing: 3) {
                        Text("Sessions start at")
                        Text(nextSessionStart, format: .dateTime.hour().minute())
                            .monospacedDigit()
                    }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Label(status, systemImage: statusImage)
                .font(.footnote)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, WakebarDesign.horizontalPadding)
        .padding(.vertical, WakebarDesign.sectionSpacing)
        .accessibilityElement(children: .combine)
    }

    private var dayLabel: String {
        guard let nextWake else { return "Next wake" }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        if calendar.isDateInToday(nextWake) {
            return "Today"
        }
        if calendar.isDateInTomorrow(nextWake) {
            return "Tomorrow"
        }
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: nextWake)
    }

    private var statusImage: String {
        switch menuState {
        case .ready:
            "checkmark.circle.fill"
        case .inProgress:
            "clock"
        case .actionRequired:
            "exclamationmark.circle"
        case .draft:
            "circle.dashed"
        }
    }

    private var statusColor: Color {
        switch menuState {
        case .ready:
            .green
        case .inProgress, .draft:
            .secondary
        case .actionRequired:
            .orange
        }
    }
}
