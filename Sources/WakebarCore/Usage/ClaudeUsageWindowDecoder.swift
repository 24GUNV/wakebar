import Foundation

/// Decodes the live Claude Code OAuth usage response into provider-reported
/// windows.
///
/// The response shape and the distinction between five-hour and seven-day
/// limits are adapted from CodexBar, which is MIT licensed. A five-hour object
/// with no utilization is the synthetic placeholder Claude Code emits when no
/// session window exists, so it is intentionally ignored — but a utilization
/// that is present and zero is a real reading of an untouched window.
public struct ClaudeUsageWindowDecoder: Sendable {
    public init() {}

    public func decode(_ body: Data, observedAt: Date) throws -> [UsageWindow] {
        do {
            let response = try JSONDecoder().decode(Response.self, from: body)
            let legacySession = Self.window(
                response.fiveHour,
                kind: .session,
                duration: 5 * 60 * 60,
                observedAt: observedAt
            )
            let legacyWeekly = Self.window(
                response.sevenDay,
                kind: .weekly,
                duration: 7 * 24 * 60 * 60,
                observedAt: observedAt
            )
            // Older payloads used a model-specific field name. Keep the aliases
            // so an endpoint rollout does not hide the Fable limit.
            let fableSource = response.sevenDayFable
                ?? response.sevenDaySonnet
                ?? response.sevenDayOpus
            let legacyWeeklyFable = Self.window(
                fableSource,
                kind: .weeklyFable,
                duration: 7 * 24 * 60 * 60,
                observedAt: observedAt
            )
            let limits = Self.windows(from: response.limits, observedAt: observedAt)

            return [
                limits[.session] ?? legacySession,
                limits[.weekly] ?? legacyWeekly,
                limits[.weeklyFable] ?? legacyWeeklyFable,
            ].compactMap { $0 }
        } catch let error as DecodingError {
            throw ClaudeUsageWindowDecodingError.invalidResponse(errorDescription: error.localizedDescription)
        }
    }

    public func decode(_ body: String, observedAt: Date) throws -> [UsageWindow] {
        try decode(Data(body.utf8), observedAt: observedAt)
    }

    private static func window(
        _ window: Window?,
        kind: UsageLimitKind,
        duration: TimeInterval,
        observedAt: Date
    ) -> UsageWindow? {
        guard let utilization = window?.utilization,
              let resetsAt = window?.resetsAt,
              let resetDate = date(from: resetsAt)
        else { return nil }

        return UsageWindow(
            provider: .claude,
            limitKind: kind,
            duration: duration,
            resetsAt: resetDate,
            usedFraction: max(0, min(1, utilization / 100)),
            observedAt: observedAt,
            confidence: .reported
        )
    }

    private static func windows(
        from limits: [Limit]?,
        observedAt: Date
    ) -> [UsageLimitKind: UsageWindow] {
        var windows: [UsageLimitKind: UsageWindow] = [:]

        for limit in limits ?? [] {
            guard let kind = limit.limitKind,
                  let percent = limit.percent,
                  let resetsAt = limit.resetsAt,
                  let resetDate = date(from: resetsAt)
            else { continue }

            windows[kind] = UsageWindow(
                provider: .claude,
                limitKind: kind,
                duration: kind == .session ? 5 * 60 * 60 : 7 * 24 * 60 * 60,
                resetsAt: resetDate,
                usedFraction: max(0, min(1, percent / 100)),
                observedAt: observedAt,
                confidence: .reported
            )
        }

        return windows
    }

    private static func date(from value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let wholeSecond = ISO8601DateFormatter()
        wholeSecond.formatOptions = [.withInternetDateTime]
        return wholeSecond.date(from: value)
    }

    private struct Response: Decodable {
        let fiveHour: Window?
        let sevenDay: Window?
        let sevenDayFable: Window?
        let sevenDayOpus: Window?
        let sevenDaySonnet: Window?
        let limits: [Limit]?

        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
            case sevenDayFable = "seven_day_fable"
            case sevenDayOpus = "seven_day_opus"
            case sevenDaySonnet = "seven_day_sonnet"
            case limits
        }
    }

    private struct Window: Decodable {
        let utilization: Double?
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    private struct Limit: Decodable {
        let kind: String?
        let percent: Double?
        let resetsAt: String?
        let scope: Scope?

        var limitKind: UsageLimitKind? {
            guard let kind else { return nil }

            return switch kind {
            case "session":
                .session
            case "weekly_all":
                .weekly
            case "weekly_scoped" where scope?.model != nil:
                .weeklyFable
            default:
                nil
            }
        }

        enum CodingKeys: String, CodingKey {
            case kind
            case percent
            case resetsAt = "resets_at"
            case scope
        }
    }

    private struct Scope: Decodable {
        let model: Model?
    }

    private struct Model: Decodable {}
}

public enum ClaudeUsageWindowDecodingError: Error, Equatable, Sendable {
    case invalidResponse(errorDescription: String)
}
