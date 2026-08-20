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
                .frame(maxWidth: .infinity, minHeight: 34)
                .contentShape(Rectangle())
                .buttonStyle(WeekdayButtonStyle(isSelected: selection.contains(weekday)))
                .accessibilityLabel(weekday.fullLabel)
                .accessibilityValue(selection.contains(weekday) ? "Selected" : "Not selected")
                .accessibilityAddTraits(selection.contains(weekday) ? .isSelected : [])
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
