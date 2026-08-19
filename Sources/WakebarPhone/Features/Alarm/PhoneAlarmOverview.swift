import SwiftUI
import WakebarCore

struct PhoneAlarmOverview: View {
    let payload: PhoneAlarmSchedulePayload

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: PhoneDesign.contentSpacing) {
                Label("Wake time", systemImage: "sunrise.fill")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(wakeTime, format: .dateTime.hour().minute())
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()

                Text(weekdaySummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary)
        }
    }

    private var wakeTime: Date {
        Calendar.current.date(
            bySettingHour: payload.hour,
            minute: payload.minute,
            second: 0,
            of: .now
        ) ?? .now
    }

    private var weekdaySummary: String {
        Weekday.displayOrder
            .filter(payload.weekdays.contains)
            .map { Calendar.current.shortWeekdaySymbols[$0.rawValue - 1] }
            .joined(separator: " · ")
    }

    private var accessibilitySummary: String {
        let days = Weekday.displayOrder
            .filter(payload.weekdays.contains)
            .map(\.fullLabel)
            .joined(separator: ", ")
        let time = wakeTime.formatted(date: .omitted, time: .shortened)
        return "Wake time \(time), \(days)"
    }
}
