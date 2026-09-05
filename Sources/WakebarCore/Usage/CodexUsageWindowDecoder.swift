import Foundation

/// Decodes the live Codex usage response into provider-reported windows.
///
/// The response shape and duration-based classification are adapted from
/// CodexBar, which is MIT licensed. The API can put the five-hour and weekly
/// windows in either slot, and some plans report only the weekly window, so
/// slot names are deliberately not used to classify the result.
public struct CodexUsageWindowDecoder: Sendable {
    public init() {}

    public func decode(_ body: Data, observedAt: Date) throws -> [UsageWindow] {
        do {
            let response = try JSONDecoder().decode(Response.self, from: body)
            guard response.hasWindowLayout else {
                throw CodexUsageWindowDecodingError.invalidResponse(
                    errorDescription: "The Codex response did not contain a recognized rate-limit layout."
                )
            }

            return response.windows
                .compactMap { $0 }
                .compactMap { window in
                    guard let duration = Self.duration(for: window.limitWindowSeconds) else {
                        return nil
                    }
                    return UsageWindow(
                        provider: .codex,
                        duration: duration,
                        resetsAt: Date(timeIntervalSince1970: TimeInterval(window.resetAt)),
                        usedFraction: max(0, min(1, window.usedPercent / 100)),
                        observedAt: observedAt,
                        confidence: .reported
                    )
                }
        } catch let error as DecodingError {
            throw CodexUsageWindowDecodingError.invalidResponse(errorDescription: error.localizedDescription)
        }
    }

    public func decode(_ body: String, observedAt: Date) throws -> [UsageWindow] {
        try decode(Data(body.utf8), observedAt: observedAt)
    }

    /// Any positive window is kept and classified by its length downstream.
    /// Whitelisting the two lengths in use today would silently drop a window
    /// the moment a plan gains a third, and a dropped window reads in the UI as
    /// a provider Wakebar cannot see at all.
    private static func duration(for seconds: Int) -> TimeInterval? {
        seconds > 0 ? TimeInterval(seconds) : nil
    }

    private struct Response: Decodable {
        let primaryWindow: Window?
        let secondaryWindow: Window?
        let rateLimit: RateLimit?
        let hasWindowLayout: Bool

        var windows: [Window?] {
            if let rateLimit {
                return [rateLimit.primaryWindow, rateLimit.secondaryWindow]
            }
            return [primaryWindow, secondaryWindow]
        }

        enum CodingKeys: String, CodingKey {
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
            case rateLimit = "rate_limit"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            primaryWindow = try container.decodeIfPresent(Window.self, forKey: .primaryWindow)
            secondaryWindow = try container.decodeIfPresent(Window.self, forKey: .secondaryWindow)
            rateLimit = try container.decodeIfPresent(RateLimit.self, forKey: .rateLimit)
            hasWindowLayout = container.contains(.primaryWindow)
                || container.contains(.secondaryWindow)
                || container.contains(.rateLimit)
        }
    }

    private struct RateLimit: Decodable {
        let primaryWindow: Window?
        let secondaryWindow: Window?

        enum CodingKeys: String, CodingKey {
            case primaryWindow = "primary_window"
            case secondaryWindow = "secondary_window"
        }
    }

    private struct Window: Decodable {
        let usedPercent: Double
        let resetAt: Int
        let limitWindowSeconds: Int

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case resetAt = "reset_at"
            case limitWindowSeconds = "limit_window_seconds"
        }
    }
}

public enum CodexUsageWindowDecodingError: Error, Equatable, Sendable {
    case invalidResponse(errorDescription: String)
}
