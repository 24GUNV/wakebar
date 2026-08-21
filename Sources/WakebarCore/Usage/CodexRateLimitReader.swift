import Foundation

/// Reads the rate-limit snapshot Codex writes into its session logs.
///
/// Codex records the API's own rate-limit headers as it works, so this is the
/// provider's account of the window rather than Wakebar's guess:
///
/// ```json
/// "rate_limits":{"primary":{"used_percent":55.0,"window_minutes":300,
///                           "resets_at":1779810921}, ...}
/// ```
///
/// The shape moves with the plan. A session-length window may be reported as
/// `primary` on one plan and `secondary` on another, and a plan with only a
/// weekly cap reports no session window at all — so both slots are read and the
/// shortest qualifying window wins, rather than trusting a position.
///
/// This is an undocumented private format. Every field is optional and a parse
/// that does not fit returns nil, because a wrong window is worse than none.
public struct CodexRateLimitReader: Sendable {
    public init() {}

    private static let marker = "\"rate_limits\":"

    /// Parses the last snapshot in one session log.
    ///
    /// - Parameter observedAt: when the log was last written, used as the
    ///   reading's age. `resets_at` is absolute so it survives staleness.
    public func window(fromSessionLog contents: String, observedAt: Date) -> UsageWindow? {
        candidates(in: contents, observedAt: observedAt)
            .filter(\.isSessionWindow)
            .min { $0.duration < $1.duration }
    }

    /// Every window in the last snapshot, session-length or not. The caller
    /// decides what a long window means.
    public func allWindows(fromSessionLog contents: String, observedAt: Date) -> [UsageWindow] {
        candidates(in: contents, observedAt: observedAt)
    }

    private func candidates(in contents: String, observedAt: Date) -> [UsageWindow] {
        guard let range = contents.range(of: Self.marker, options: .backwards) else { return [] }
        let tail = contents[range.upperBound...]
        guard let object = Self.firstJSONObject(in: tail) else { return [] }

        return ["primary", "secondary"].compactMap { key in
            guard let slot = object[key] as? [String: Any] else { return nil }
            return Self.window(from: slot, observedAt: observedAt)
        }
    }

    private static func window(from slot: [String: Any], observedAt: Date) -> UsageWindow? {
        guard let minutes = slot["window_minutes"] as? Double ?? (slot["window_minutes"] as? Int).map(Double.init),
              minutes > 0,
              let resets = slot["resets_at"] as? Double ?? (slot["resets_at"] as? Int).map(Double.init)
        else { return nil }

        let used = slot["used_percent"] as? Double ?? (slot["used_percent"] as? Int).map(Double.init)

        return UsageWindow(
            provider: .codex,
            duration: minutes * 60,
            resetsAt: Date(timeIntervalSince1970: resets),
            usedFraction: used.map { $0 / 100 },
            observedAt: observedAt,
            confidence: .reported
        )
    }

    /// Scans for the balanced object that starts the slice. The snapshot sits
    /// inside a larger line, so the object cannot simply be handed to
    /// `JSONSerialization` whole.
    private static func firstJSONObject(in slice: Substring) -> [String: Any]? {
        var depth = 0
        var inString = false
        var isEscaped = false
        var start: String.Index?

        for index in slice.indices {
            let character = slice[index]

            if isEscaped {
                isEscaped = false
                continue
            }
            if character == "\\" {
                isEscaped = true
                continue
            }
            if character == "\"" {
                inString.toggle()
                continue
            }
            guard !inString else { continue }

            if character == "{" {
                if depth == 0 { start = index }
                depth += 1
            } else if character == "}" {
                depth -= 1
                guard depth <= 0 else { continue }
                guard let start else { return nil }
                let json = String(slice[start...index])
                return (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any]
            }
        }
        return nil
    }
}
