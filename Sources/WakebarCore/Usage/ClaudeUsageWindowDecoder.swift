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
            let session = Self.window(response.fiveHour, duration: 5 * 60 * 60, observedAt: observedAt)

            // seven_day is the account cap and the opus and sonnet entries are
            // sub-caps of it: three readings of one weekly limit, not three
            // limits. Only the one that stops work first is worth a row, since
            // the other two would render as the same label and the same word
            // twice over.
            let weekly = [response.sevenDay, response.sevenDayOpus, response.sevenDaySonnet]
                .compactMap { Self.window($0, duration: 7 * 24 * 60 * 60, observedAt: observedAt) }
                .max { ($0.usedFraction ?? 0) < ($1.usedFraction ?? 0) }

            return [session, weekly].compactMap { $0 }
        } catch let error as DecodingError {
            throw ClaudeUsageWindowDecodingError.invalidResponse(errorDescription: error.localizedDescription)
        }
    }

    public func decode(_ body: String, observedAt: Date) throws -> [UsageWindow] {
        try decode(Data(body.utf8), observedAt: observedAt)
    }

    private static func window(
        _ window: Window?,
        duration: TimeInterval,
        observedAt: Date
    ) -> UsageWindow? {
        guard let utilization = window?.utilization,
              let resetsAt = window?.resetsAt,
              let resetDate = date(from: resetsAt)
        else { return nil }

        return UsageWindow(
            provider: .claude,
            duration: duration,
            resetsAt: resetDate,
            usedFraction: max(0, min(1, utilization / 100)),
            observedAt: observedAt,
            confidence: .reported
        )
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
        let sevenDayOpus: Window?
        let sevenDaySonnet: Window?

        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
            case sevenDayOpus = "seven_day_opus"
            case sevenDaySonnet = "seven_day_sonnet"
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
}

public enum ClaudeUsageWindowDecodingError: Error, Equatable, Sendable {
    case invalidResponse(errorDescription: String)
}
