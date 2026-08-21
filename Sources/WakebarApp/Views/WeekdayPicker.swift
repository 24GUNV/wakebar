import SwiftUI
import WakebarCore

/// The week as one strip rather than seven separate buttons.
///
/// Selected days merge into a single run, so "weekdays" reads as one bar with
/// the weekend left out — the shape carries the answer before any letter is
/// read. Dragging across the strip selects a stretch in one gesture, which is
/// the motion the answer usually wants.
struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>

    @Environment(\.calendar) private var calendar
    /// What a drag started out doing. A drag that begins on a chosen day clears
    /// the days it crosses; one that begins on an empty day fills them. Deciding
    /// once at the start is what keeps a drag from flickering under the finger.
    @State private var dragIntent: Bool?

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width / CGFloat(orderedWeekdays.count)

            HStack(spacing: 0) {
                ForEach(Array(orderedWeekdays.enumerated()), id: \.element) { index, weekday in
                    cell(for: weekday, at: index)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard width > 0, value.location.x >= 0 else { return }
                        // Truncation toward zero turns any negative x into index
                        // 0, so without the guard above, dragging off the leading
                        // edge quietly paints Sunday. Off the trailing edge the
                        // index simply falls outside the range and nothing
                        // happens, and both edges should behave the same way.
                        let index = Int(value.location.x / width)
                        guard orderedWeekdays.indices.contains(index) else { return }
                        let weekday = orderedWeekdays[index]

                        let intent = dragIntent ?? !selection.contains(weekday)
                        dragIntent = intent
                        apply(intent, to: weekday)
                    }
                    .onEnded { _ in dragIntent = nil }
            )
        }
        .frame(height: WakebarDesign.weekdayButtonHeight)
        .frame(minWidth: WakebarDesign.weekdayButtonMinimumWidth * CGFloat(orderedWeekdays.count))
        .background {
            trackShape.fill(Color.primary.opacity(0.045))
        }
        .overlay {
            trackShape.strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
        }
        .clipShape(trackShape)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Days")
    }

    // MARK: - Cells

    private func cell(for weekday: Weekday, at index: Int) -> some View {
        let isSelected = selection.contains(weekday)

        return Text(weekday.shortLabel)
            .font(WakebarDesign.weekdayLabel)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(isSelected ? Color(nsColor: .alternateSelectedControlTextColor) : .primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if isSelected {
                    runShape(at: index).fill(Color.accentColor)
                }
            }
            .animation(.easeOut(duration: 0.12), value: isSelected)
            .accessibilityElement()
            .accessibilityLabel(weekday.fullLabel)
            .accessibilityValue(isSelected ? "Selected" : "Not selected")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { apply(!isSelected, to: weekday) }
    }

    /// A selected day rounds only where its run ends, so neighbours read as one
    /// stretch instead of a row of separate pills.
    private func runShape(at index: Int) -> UnevenRoundedRectangle {
        let radius = WakebarDesign.controlRadius
        let opensRun = !isSelected(at: index - 1)
        let closesRun = !isSelected(at: index + 1)

        return UnevenRoundedRectangle(
            topLeadingRadius: opensRun ? radius : 0,
            bottomLeadingRadius: opensRun ? radius : 0,
            bottomTrailingRadius: closesRun ? radius : 0,
            topTrailingRadius: closesRun ? radius : 0,
            style: .continuous
        )
    }

    private var trackShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: WakebarDesign.controlRadius + 1, style: .continuous)
    }

    // MARK: - Selection

    private var orderedWeekdays: [Weekday] {
        Weekday.displayOrder(for: calendar)
    }

    private func isSelected(at index: Int) -> Bool {
        guard orderedWeekdays.indices.contains(index) else { return false }
        return selection.contains(orderedWeekdays[index])
    }

    private func apply(_ isSelected: Bool, to weekday: Weekday) {
        if isSelected {
            selection.insert(weekday)
        } else {
            selection.remove(weekday)
        }
    }
}
