import SwiftUI
import WakebarCore

/// The instrument at the top of the popover: when Wakebar next does something,
/// and the two switches that govern it — whether it runs at all, and which clock
/// it runs on.
///
/// It deliberately carries no overall status line. Every value the schedule's
/// status can take is already the value of one of the rows underneath, and
/// printing the same two words twice in one 300pt panel reads as filler.
struct WakeCountdownView: View {
    let nextFire: Date?
    let cadence: SessionCadence
    let wakeTimeText: String
    let weekdaySummary: String
    @Binding var isActive: Bool
    let onCadenceChange: (SessionCadence) -> Void

    @Environment(\.timeZone) private var timeZone

    /// Past a day out a duration stops being actionable — nobody plans against
    /// "2d 15h" — so the hero switches to naming the day instead.
    private static let durationHorizon: TimeInterval = 24 * 60 * 60

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let hero = heroText(at: context.date)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: WakebarDesign.compactSpacing) {
                        Text(hero)
                            .font(WakebarDesign.hero)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.25), value: hero)
                            .foregroundStyle(isActive ? Color.primary : Color.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Spacer(minLength: WakebarDesign.compactSpacing)

                        Toggle("Wake schedule", isOn: $isActive)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .accessibilityLabel("Wake schedule")
                    }

                    Text(subline(at: context.date))
                        .font(WakebarDesign.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            CadencePicker(cadence: cadence, isEnabled: isActive, onChange: onCadenceChange)
                .padding(.top, 10)
        }
        .wakebarInset()
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Content

    /// Close in, the answer is how long you have. Far out, the answer is which
    /// day it lands on — the same fact, told in the unit that is usable at that
    /// distance.
    private func heroText(at now: Date) -> String {
        guard isActive else { return "Off" }
        guard let nextFire else { return "Nothing planned" }

        let interval = nextFire.timeIntervalSince(now)
        guard interval >= Self.durationHorizon else {
            return Self.countdown(from: now, to: nextFire)
        }
        return dayName(for: nextFire)
    }

    /// The hero's other half. When the hero counts down this names the moment;
    /// when the hero names a day this gives the time on it. Either way it says
    /// which of the two things Wakebar does is being counted, because the hero
    /// alone cannot distinguish a wake from a session.
    private func subline(at now: Date) -> String {
        guard isActive else { return "\(wakeTimeText) · \(weekdaySummary)" }
        guard let nextFire else {
            return cadence == .continuous ? "No providers selected" : "\(wakeTimeText) · \(weekdaySummary)"
        }

        let clock = nextFire.formatted(.dateTime.hour().minute())
        let noun = cadence == .continuous ? "Session" : "Wake"

        // The day is already the hero out here, so repeating it would be the
        // same word twice in two sizes.
        if nextFire.timeIntervalSince(now) >= Self.durationHorizon {
            return "\(noun) at \(clock)"
        }
        return "\(noun) at \(clock) \(dayLabel(for: nextFire))"
    }

    /// "in 8h 12m" reads as a duration at a glance; a clock time does not.
    static func countdown(from now: Date, to fire: Date) -> String {
        let totalMinutes = Int(max(0, fire.timeIntervalSince(now)) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 { return "in \(hours)h \(minutes)m" }
        if minutes > 0 { return "in \(minutes)m" }
        return "in under a minute"
    }

    private func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date)
    }

    private func dayLabel(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInTomorrow(date) { return "tomorrow" }
        return dayName(for: date)
    }
}

/// The quick switch between the two clocks. It sits in the popover rather than
/// settings because it is the one setting a user changes for a single day —
/// "keep it open while I work today" is a different answer from "wake me at 7".
private struct CadencePicker: View {
    let cadence: SessionCadence
    let isEnabled: Bool
    let onChange: (SessionCadence) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SessionCadence.allCases) { option in
                segment(option)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: WakebarDesign.controlRadius + 2, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Session cadence")
    }

    private func segment(_ option: SessionCadence) -> some View {
        let isSelected = option == cadence
        return Button {
            onChange(option)
        } label: {
            Text(option.displayName)
                .font(WakebarDesign.rowValue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
        }
        .buttonStyle(CadenceSegmentStyle(isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct CadenceSegmentStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .background(
                RoundedRectangle(cornerRadius: WakebarDesign.controlRadius, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(.selection.opacity(0.9)) : AnyShapeStyle(.clear))
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.12), value: isSelected)
    }
}
