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

    public static let displayOrder: [Self] = [
        .monday,
        .tuesday,
        .wednesday,
        .thursday,
        .friday,
        .saturday,
        .sunday,
    ]

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
