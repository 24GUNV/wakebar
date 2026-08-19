import Foundation

public struct ProviderSnapshot: Identifiable, Equatable, Sendable {
    public let provider: ProviderID
    public let availability: ProviderAvailability
    public let fiveHourRemaining: Double?
    public let fiveHourReset: Date?
    public let weeklyRemaining: Double?
    public let weeklyReset: Date?

    public var id: ProviderID { provider }

    public var menuLabel: String {
        if let exceptionalMenuText = availability.exceptionalMenuText {
            "\(provider.displayName) — \(exceptionalMenuText)"
        } else {
            provider.displayName
        }
    }

    public var fiveHourMenuText: String {
        usageText(label: "Five-hour", remaining: fiveHourRemaining, reset: fiveHourReset, includesWeekday: false)
    }

    public var weeklyMenuText: String {
        usageText(label: "Weekly", remaining: weeklyRemaining, reset: weeklyReset, includesWeekday: true)
    }

    public static func notConnected(_ provider: ProviderID) -> Self {
        Self(
            provider: provider,
            availability: .notConnected,
            fiveHourRemaining: nil,
            fiveHourReset: nil,
            weeklyRemaining: nil,
            weeklyReset: nil
        )
    }

    private func usageText(
        label: String,
        remaining: Double?,
        reset: Date?,
        includesWeekday: Bool
    ) -> String {
        guard let remaining else {
            return "\(label) usage unavailable"
        }

        let percentage = remaining.formatted(.percent.precision(.fractionLength(0)))
        guard let reset else {
            return "\(label): \(percentage) remaining"
        }

        let resetText = if includesWeekday {
            reset.formatted(.dateTime.weekday(.wide).hour().minute())
        } else {
            reset.formatted(.dateTime.hour().minute())
        }

        return "\(label): \(percentage) remaining · resets \(resetText)"
    }
}
