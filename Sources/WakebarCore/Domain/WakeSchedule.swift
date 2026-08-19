import Foundation

public struct WakeSchedule: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var revision: UUID
    public var isEnabled: Bool
    public var hour: Int
    public var minute: Int
    public var selectedWeekdays: Set<Weekday>
    public var sessionLeadMinutes: Int
    public var alarmOnIPhone: Bool
    public var repeatEveryFiveHours: Bool
    public var repeatUntilHour: Int
    public var includeClaude: Bool
    public var includeCodex: Bool
    public var claudeBackend: ExecutionBackend
    public var codexBackend: ExecutionBackend
    public var codexRoute: CodexSchedulingRoute
    public var followsSystemTimeZone: Bool
    public var timeZoneIdentifier: String
    public var skippedWakeDate: Date?

    public init(
        id: UUID,
        revision: UUID = UUID(),
        isEnabled: Bool,
        hour: Int,
        minute: Int,
        selectedWeekdays: Set<Weekday>,
        sessionLeadMinutes: Int,
        alarmOnIPhone: Bool,
        repeatEveryFiveHours: Bool,
        repeatUntilHour: Int,
        includeClaude: Bool,
        includeCodex: Bool,
        claudeBackend: ExecutionBackend,
        codexBackend: ExecutionBackend,
        codexRoute: CodexSchedulingRoute = .chatGPTWebTask,
        followsSystemTimeZone: Bool,
        timeZoneIdentifier: String,
        skippedWakeDate: Date? = nil
    ) {
        self.id = id
        self.revision = revision
        self.isEnabled = isEnabled
        self.hour = hour
        self.minute = minute
        self.selectedWeekdays = selectedWeekdays
        self.sessionLeadMinutes = sessionLeadMinutes
        self.alarmOnIPhone = alarmOnIPhone
        self.repeatEveryFiveHours = repeatEveryFiveHours
        self.repeatUntilHour = repeatUntilHour
        self.includeClaude = includeClaude
        self.includeCodex = includeCodex
        self.claudeBackend = claudeBackend
        self.codexBackend = codexBackend
        self.codexRoute = codexRoute
        self.followsSystemTimeZone = followsSystemTimeZone
        self.timeZoneIdentifier = timeZoneIdentifier
        self.skippedWakeDate = skippedWakeDate
    }

    public var providerIDs: [ProviderID] {
        ProviderID.allCases.filter { provider in
            switch provider {
            case .claude:
                includeClaude
            case .codex:
                includeCodex
            }
        }
    }

    public var timeZone: TimeZone {
        if followsSystemTimeZone {
            .autoupdatingCurrent
        } else {
            TimeZone(identifier: timeZoneIdentifier) ?? .autoupdatingCurrent
        }
    }

    public var isValid: Bool {
        !providerIDs.isEmpty && !selectedWeekdays.isEmpty
    }

    public func backend(for provider: ProviderID) -> ExecutionBackend {
        switch provider {
        case .claude:
            claudeBackend
        case .codex:
            codexRoute.executionBackend
        }
    }

    public static var `default`: Self {
        Self(
            id: UUID(),
            revision: UUID(),
            isEnabled: true,
            hour: 7,
            minute: 0,
            selectedWeekdays: Weekday.workweek,
            sessionLeadMinutes: 10,
            alarmOnIPhone: true,
            repeatEveryFiveHours: false,
            repeatUntilHour: 19,
            includeClaude: true,
            includeCodex: true,
            claudeBackend: .providerCloud,
            codexBackend: .providerCloud,
            codexRoute: .chatGPTWebTask,
            followsSystemTimeZone: true,
            timeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case revision
        case isEnabled
        case hour
        case minute
        case selectedWeekdays
        case sessionLeadMinutes
        case alarmOnIPhone
        case repeatEveryFiveHours
        case repeatUntilHour
        case includeClaude
        case includeCodex
        case claudeBackend
        case codexBackend
        case codexRoute
        case followsSystemTimeZone
        case timeZoneIdentifier
        case skippedWakeDate
        case weekdaysOnly
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let legacyWeekdaysOnly = try values.decodeIfPresent(Bool.self, forKey: .weekdaysOnly) ?? true

        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        revision = try values.decodeIfPresent(UUID.self, forKey: .revision) ?? UUID()
        isEnabled = try values.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        hour = try values.decodeIfPresent(Int.self, forKey: .hour) ?? 7
        minute = try values.decodeIfPresent(Int.self, forKey: .minute) ?? 0
        selectedWeekdays = try values.decodeIfPresent(Set<Weekday>.self, forKey: .selectedWeekdays)
            ?? (legacyWeekdaysOnly ? Weekday.workweek : Set(Weekday.allCases))
        sessionLeadMinutes = try values.decodeIfPresent(Int.self, forKey: .sessionLeadMinutes) ?? 10
        alarmOnIPhone = try values.decodeIfPresent(Bool.self, forKey: .alarmOnIPhone) ?? true
        repeatEveryFiveHours = try values.decodeIfPresent(Bool.self, forKey: .repeatEveryFiveHours) ?? false
        repeatUntilHour = try values.decodeIfPresent(Int.self, forKey: .repeatUntilHour) ?? 19
        includeClaude = try values.decodeIfPresent(Bool.self, forKey: .includeClaude) ?? true
        includeCodex = try values.decodeIfPresent(Bool.self, forKey: .includeCodex) ?? true
        claudeBackend = try values.decodeIfPresent(ExecutionBackend.self, forKey: .claudeBackend) ?? .providerCloud
        codexBackend = try values.decodeIfPresent(ExecutionBackend.self, forKey: .codexBackend) ?? .providerCloud
        codexRoute = try values.decodeIfPresent(CodexSchedulingRoute.self, forKey: .codexRoute)
            ?? Self.legacyCodexRoute(for: codexBackend)
        followsSystemTimeZone = try values.decodeIfPresent(Bool.self, forKey: .followsSystemTimeZone) ?? true
        timeZoneIdentifier = try values.decodeIfPresent(String.self, forKey: .timeZoneIdentifier)
            ?? TimeZone.autoupdatingCurrent.identifier
        skippedWakeDate = try values.decodeIfPresent(Date.self, forKey: .skippedWakeDate)
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(revision, forKey: .revision)
        try values.encode(isEnabled, forKey: .isEnabled)
        try values.encode(hour, forKey: .hour)
        try values.encode(minute, forKey: .minute)
        try values.encode(selectedWeekdays, forKey: .selectedWeekdays)
        try values.encode(sessionLeadMinutes, forKey: .sessionLeadMinutes)
        try values.encode(alarmOnIPhone, forKey: .alarmOnIPhone)
        try values.encode(repeatEveryFiveHours, forKey: .repeatEveryFiveHours)
        try values.encode(repeatUntilHour, forKey: .repeatUntilHour)
        try values.encode(includeClaude, forKey: .includeClaude)
        try values.encode(includeCodex, forKey: .includeCodex)
        try values.encode(claudeBackend, forKey: .claudeBackend)
        try values.encode(codexBackend, forKey: .codexBackend)
        try values.encode(codexRoute, forKey: .codexRoute)
        try values.encode(followsSystemTimeZone, forKey: .followsSystemTimeZone)
        try values.encode(timeZoneIdentifier, forKey: .timeZoneIdentifier)
        try values.encodeIfPresent(skippedWakeDate, forKey: .skippedWakeDate)
    }

    private static func legacyCodexRoute(for backend: ExecutionBackend) -> CodexSchedulingRoute {
        switch backend {
        case .providerCloud:
            .chatGPTWebTask
        case .thisMac:
            .localCLI
        case .alwaysOnRunner:
            .alwaysOnRunner
        }
    }
}
