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
                .frame(maxWidth: .infinity, minHeight: 32)
                .foregroundStyle(.primary)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selection.contains(weekday) ? Color.primary.opacity(0.10) : Color.clear)
                        .stroke(selection.contains(weekday) ? Color.primary.opacity(0.30) : Color.secondary.opacity(0.35), lineWidth: 1)
                }
                .accessibilityLabel(weekday.fullLabel)
                .accessibilityValue(selection.contains(weekday) ? "Selected" : "Not selected")
                .accessibilityAddTraits(selection.contains(weekday) ? .isSelected : [])
                .disabled(selection.contains(weekday) && selection.count == 1)
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
