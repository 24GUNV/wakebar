/// The menu bar icon's one glance of state: a wake is scheduled, something
/// needs the user, or the schedule is off. Attention only exists while the
/// schedule is on — a switched-off schedule with unfinished setup is expected,
/// not an error.
public enum MenuBarIconState: Equatable, Sendable {
    case active
    case attention
    case off

    public static func resolve(
        isScheduleEnabled: Bool,
        menuState: ScheduleMenuState
    ) -> Self {
        guard isScheduleEnabled else { return .off }
        return menuState == .actionRequired ? .attention : .active
    }

    /// The filled sunrise means a wake is scheduled and the outline means off.
    /// State never changes the glyph family, so the item stays findable.
    public var symbolName: String {
        self == .off ? "sunrise" : "sunrise.fill"
    }

    /// Menu-bar icons stay template monochrome, so attention reads as a badge,
    /// never as color.
    public var badgeSymbolName: String? {
        self == .attention ? "exclamationmark.circle.fill" : nil
    }

    public var accessibilityLabel: String {
        switch self {
        case .active: "Wakebar, wake scheduled"
        case .attention: "Wakebar, needs attention"
        case .off: "Wakebar, off"
        }
    }
}
