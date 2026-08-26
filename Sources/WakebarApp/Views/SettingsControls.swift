import SwiftUI
import WakebarCore

/// The System Settings tile: a white glyph on a small tinted rounded
/// rectangle. It marks a row that stands for a whole service, the way System
/// Settings marks each pane — ordinary rows stay bare so the tiles keep
/// meaning something.
struct SettingsIconTile: View {
    let symbol: String
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: WakebarDesign.settingsTileRadius, style: .continuous)
            .fill(tint.gradient)
            .frame(width: WakebarDesign.settingsTileSize, height: WakebarDesign.settingsTileSize)
            .overlay {
                Image(systemName: symbol)
                    .font(WakebarDesign.settingsTileGlyph)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

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
