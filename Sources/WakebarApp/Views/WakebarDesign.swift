import SwiftUI

/// Shared layout, rhythm, and type decisions for the menu bar surface.
///
/// The popover reads as an instrument panel: one hero number, one accent, and
/// quiet single-line rows beneath it. Sizes are fixed rather than derived from
/// the system text styles so the hierarchy holds in the menu bar, where the
/// popover cannot grow to absorb larger text.
enum WakebarDesign {
    // MARK: - Layout

    static let minimumPopoverWidth: CGFloat = 280
    static let popoverWidth: CGFloat = 300
    static let maximumPopoverWidth: CGFloat = 340

    static let horizontalPadding: CGFloat = 14
    static let compactSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 14

    // MARK: - Rhythm

    /// Vertical padding inside one row.
    static let rowPadding: CGFloat = 5
    /// Vertical padding for a divided band.
    static let bandPadding: CGFloat = 10

    static let progressBarHeight: CGFloat = 3
    static let controlRadius: CGFloat = 5

    // MARK: - Type

    /// Small tracked capitals labelling a band. Never carries data.
    static let eyebrow = Font.system(size: 9, weight: .semibold)
    /// The single hero number in the popover.
    static let hero = Font.system(size: 22, weight: .semibold, design: .rounded)
    /// A row's identity.
    static let rowTitle = Font.system(size: 12, weight: .medium)
    /// A row's state or value.
    static let rowValue = Font.system(size: 11, weight: .regular)
    /// Supporting detail that should recede.
    static let detail = Font.system(size: 11, weight: .regular)
    static let badge = Font.system(size: 8, weight: .semibold)
    /// The warning glyph beside a row value. Optically matched to `rowValue`.
    static let statusGlyph = Font.system(size: 10, weight: .semibold)

    static let eyebrowTracking: CGFloat = 0.6

    // MARK: - Settings

    /// The settings window runs at the system control scale, so it gets its own
    /// inset rather than borrowing the popover's tighter 14pt one. Everything
    /// else — rhythm, status vocabulary, accent — is shared.
    static let windowPadding: CGFloat = 20
    static let windowMinimumWidth: CGFloat = 500
    static let windowMinimumHeight: CGFloat = 420
    /// A provider setup sheet. Wide enough for one status row and one action,
    /// and no wider — it is a decision, not a document.
    static let sheetWidth: CGFloat = 420
    static let sheetMinimumHeight: CGFloat = 200

    /// One day toggle in the settings weekday picker. Sized to the window's 13pt
    /// control text, not the popover's smaller scale, and deliberately given a
    /// definite width: the row sits in a value column, so it must not fight the
    /// label for space the way a flexible control would.
    static let weekdayButtonHeight: CGFloat = 26
    static let weekdayButtonMinimumWidth: CGFloat = 30
    /// The day letter. Kept under the 13pt control size so seven of them read as
    /// one control rather than as seven buttons.
    static let weekdayLabel = Font.system(size: 12)

    /// The warning glyph beside a settings row value, optically matched to the
    /// window's 13pt control text the way `statusGlyph` is to the popover's 11pt.
    static let windowStatusGlyph = Font.system(size: 12, weight: .semibold)
}

extension View {
    /// A tracked, uppercased band label.
    func wakebarEyebrow() -> some View {
        self
            .font(WakebarDesign.eyebrow)
            .tracking(WakebarDesign.eyebrowTracking)
            .textCase(.uppercase)
            .foregroundStyle(.tertiary)
    }

    /// Standard horizontal inset for popover content.
    func wakebarInset() -> some View {
        padding(.horizontal, WakebarDesign.horizontalPadding)
    }
}
