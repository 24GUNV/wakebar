import Foundation

public enum Weekday: Int, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    public var id: Self { self }

    /// A fixed Monday-first order, for anything that must not shift with the
    /// reader: stored values, provider prompts, test expectations.
    public static let displayOrder: [Self] = [
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
        .saturday,
        .sunday,
    ]

    /// The week as the reader's own calendar starts it. Anything shown on
    /// screen uses this, so a US reader never sees Monday first in one place
    /// and Sunday first in another.
    ///
    /// `rawValue` already follows `Calendar`'s convention (1 = Sunday), so the
    /// first weekday indexes directly into the rotation.
    public static func displayOrder(for calendar: Calendar) -> [Self] {
        let first = calendar.firstWeekday - 1
        return (0..<allCases.count).compactMap { offset in
            Self(rawValue: (first + offset) % allCases.count + 1)
        }
    }

    public static let workweek: Set<Self> = [
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
    ]

    public var shortLabel: String {
        Calendar.current.veryShortWeekdaySymbols[rawValue - 1]
    }

    public var fullLabel: String {
        Calendar.current.weekdaySymbols[rawValue - 1]
    }
}
