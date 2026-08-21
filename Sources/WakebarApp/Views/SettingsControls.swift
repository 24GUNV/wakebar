import SwiftUI
import WakebarCore

/// A row's value in the settings window, told the way the popover tells it: the
/// state word on its own, and a glyph only on the row that needs the user.
///
/// It reads its colour and its glyph from `ServiceStatusKind`, the same source
/// `ServiceStatusRow` reads, so one situation can never end up with two
/// vocabularies across the two surfaces.
struct WindowStatusValue: View {
    let text: String
    let kind: ServiceStatusKind
    /// One line in a row, where truncation is the right answer. The bottom bar
    /// raises it, because a notice there is the whole message.
    var lineLimit: Int = 1

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let symbol = kind.statusSymbol {
                Image(systemName: symbol)
                    .font(WakebarDesign.windowStatusGlyph)
                    .accessibilityHidden(true)
            }

            Text(text)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(kind.statusColor)
        .accessibilityElement(children: .combine)
    }
}
