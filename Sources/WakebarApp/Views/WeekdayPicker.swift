import SwiftUI
import WakebarCore

struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: WakebarDesign.compactSpacing) {
            ForEach(Weekday.displayOrder) { weekday in
                Button(weekday.shortLabel) {
                    toggle(weekday)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 28)
                .foregroundStyle(selection.contains(weekday) ? Color.white : Color.primary)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selection.contains(weekday) ? Color.accentColor : Color.clear)
                        .stroke(selection.contains(weekday) ? Color.accentColor : Color.secondary, lineWidth: 1)
                }
                .accessibilityLabel(weekday.fullLabel)
                .accessibilityValue(selection.contains(weekday) ? "Selected" : "Not selected")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Repeat days")
    }

    private func toggle(_ weekday: Weekday) {
        if selection.contains(weekday) {
            selection.remove(weekday)
        } else {
            selection.insert(weekday)
        }
    }
}
