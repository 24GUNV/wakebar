import SwiftUI
import WakebarCore

extension ServiceStatusKind {
    /// Only a row that needs the user takes colour. Keeping the healthy states
    /// grey is what lets the one problem row read at a glance.
    var needsAttention: Bool {
        self == .actionRequired
    }

    var statusColor: Color {
        needsAttention ? .orange : .secondary
    }

    /// The popover's only glyph. It shows up on the one row that needs the
    /// user and nowhere else, which is the whole reason it reads.
    var statusSymbol: String? {
        needsAttention ? "exclamationmark.triangle.fill" : nil
    }
}

/// A quiet qualifier that rides beside a row title, for facts that are not a
/// status: "experimental", "beta". Never used to carry state.
struct RowBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(WakebarDesign.badge)
            .tracking(WakebarDesign.eyebrowTracking)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.quaternary)
            )
    }
}

/// The popover's one interactive surface treatment: a row that lights up under
/// the pointer and dips on press, so anything clickable looks clickable.
struct PopoverRowButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, WakebarDesign.compactSpacing)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: WakebarDesign.controlRadius, style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? 0.07 : 0))
            )
            .contentShape(
                RoundedRectangle(cornerRadius: WakebarDesign.controlRadius, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

/// The footer variant: same hover treatment, sized to its label so the row can
/// hold more than one control.
struct PopoverFooterButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WakebarDesign.rowValue)
            .padding(.horizontal, WakebarDesign.compactSpacing)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: WakebarDesign.controlRadius, style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? 0.07 : 0))
            )
            .contentShape(
                RoundedRectangle(cornerRadius: WakebarDesign.controlRadius, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .onHover { isHovering = $0 }
    }
}
