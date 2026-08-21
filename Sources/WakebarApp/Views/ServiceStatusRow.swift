import SwiftUI
import WakebarCore

/// One service, told in a single line: what it is on the left, what state it is
/// in on the right.
///
/// Healthy rows carry no icon at all — an icon on every row makes none of them
/// mean anything. Only a row that needs the user gets a glyph, and it sits with
/// the value it qualifies rather than on a coloured rail in the margin.
struct ServiceStatusRow: View {
    let title: String
    let status: String
    let kind: ServiceStatusKind
    var badge: String?
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(PopoverRowButtonStyle())
        } else {
            content
                .padding(.horizontal, WakebarDesign.compactSpacing)
                .padding(.vertical, WakebarDesign.rowPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var content: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(WakebarDesign.rowTitle)
                .foregroundStyle(.primary)
                .lineLimit(1)

            if let badge {
                RowBadge(text: badge)
            }

            Spacer(minLength: WakebarDesign.compactSpacing)

            HStack(spacing: 4) {
                if let symbol = kind.statusSymbol {
                    Image(systemName: symbol)
                        .font(WakebarDesign.statusGlyph)
                        .accessibilityHidden(true)
                }

                Text(status)
                    .font(WakebarDesign.rowValue)
                    .lineLimit(1)
            }
            .foregroundStyle(kind.statusColor)
            .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
    }
}
