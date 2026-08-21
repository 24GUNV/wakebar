import Foundation
import WakebarCore

/// Reads the open usage windows out of the CLIs' own session logs.
///
/// Codex writes its rate-limit headers into the rollout log verbatim, so its
/// window is fact. Claude writes no such thing, so its window is reconstructed
/// from message timestamps and is reported as an estimate.
///
/// It is an actor because the logs are large and append-only: each file is
/// scanned once, and later refreshes read only the bytes that arrived since.
actor SessionLogUsageWindowReader: UsageWindowReading {
    private struct Cursor {
        var offset: UInt64
        var timestamps: [Date]
    }

    /// How far back a session still counts. Anything older cannot belong to an
    /// open five-hour block, so there is no reason to keep reading it.
    private let lookback: TimeInterval
    /// The most recent Codex logs to try. A session that never reached the API
    /// carries no rate-limit snapshot, so the newest file is not always the one
    /// with the answer.
    private let codexLogsToScan: Int
    private let codexSessionsDirectory: URL
    private let claudeProjectsDirectory: URL
    private let fileManager: FileManager
    private let rateLimitReader = CodexRateLimitReader()
    private let blockCalculator = ClaudeUsageBlockCalculator()

    private var claudeCursors: [String: Cursor] = [:]

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        lookback: TimeInterval = 12 * 60 * 60,
        codexLogsToScan: Int = 5,
        fileManager: FileManager = .default
    ) {
        self.codexSessionsDirectory = homeDirectory.appending(path: ".codex/sessions")
        self.claudeProjectsDirectory = homeDirectory.appending(path: ".claude/projects")
        self.lookback = lookback
        self.codexLogsToScan = codexLogsToScan
        self.fileManager = fileManager
    }

    func currentWindows(now: Date) async -> [UsageWindow] {
        var windows = codexWindows(now: now)
        if let claude = claudeWindow(now: now) {
            windows.append(claude)
        }
        return windows
    }

    // MARK: - Codex

    /// Every window the snapshot reports, not just the one a session could
    /// reopen. A weekly cap cannot drive scheduling, but it is the only usage
    /// figure Codex publishes on a day when no session window is open, and
    /// dropping it would leave the user with nothing.
    private func codexWindows(now: Date) -> [UsageWindow] {
        for url in recentLogs(in: codexSessionsDirectory, limit: codexLogsToScan, now: now) {
            guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let open = rateLimitReader
                .allWindows(fromSessionLog: contents, observedAt: now)
                .filter { $0.isOpen(at: now) }
            if !open.isEmpty { return open }
        }
        return []
    }

    // MARK: - Claude

    private func claudeWindow(now: Date) -> UsageWindow? {
        let logs = recentLogs(in: claudeProjectsDirectory, limit: .max, now: now)
        let live = Set(logs.map(\.path))
        claudeCursors = claudeCursors.filter { live.contains($0.key) }

        var timestamps: [Date] = []
        for url in logs {
            timestamps.append(contentsOf: claudeTimestamps(in: url, now: now))
        }

        return blockCalculator.currentWindow(timestamps: timestamps, now: now)
    }

    /// Rescans only what the file grew by, then drops whatever has aged out of
    /// the lookback so the cache cannot grow without bound.
    private func claudeTimestamps(in url: URL, now: Date) -> [Date] {
        let cutoff = now.addingTimeInterval(-lookback)
        var cursor = claudeCursors[url.path] ?? Cursor(offset: 0, timestamps: [])

        if let size = fileSize(of: url) {
            if size < cursor.offset {
                // Truncated or replaced: the offset means nothing now.
                cursor = Cursor(offset: 0, timestamps: [])
            }
            if size > cursor.offset {
                if let data = readBytes(of: url, from: cursor.offset) {
                    cursor.timestamps.append(contentsOf: Self.timestamps(in: data))
                }
                cursor.offset = size
            }
        }

        cursor.timestamps = cursor.timestamps.filter { $0 >= cutoff }
        claudeCursors[url.path] = cursor
        return cursor.timestamps
    }

    /// Pulls `"timestamp":"…"` values straight out of the bytes. Decoding 50 MB
    /// of JSON to reach one field per line would cost far more than the answer
    /// is worth, and every entry carries the field in the same shape.
    static func timestamps(in data: Data) -> [Date] {
        let marker = Array(#""timestamp":""#.utf8)
        let quote = UInt8(ascii: "\"")
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let whole = ISO8601DateFormatter()
        whole.formatOptions = [.withInternetDateTime]

        var results: [Date] = []
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard raw.count > marker.count else { return }
            var index = 0
            let limit = raw.count - marker.count
            while index <= limit {
                guard raw[index] == quote else {
                    index += 1
                    continue
                }
                var offset = 1
                while offset < marker.count, raw[index + offset] == marker[offset] {
                    offset += 1
                }
                guard offset == marker.count else {
                    index += 1
                    continue
                }

                let valueStart = index + marker.count
                var valueEnd = valueStart
                while valueEnd < raw.count, raw[valueEnd] != quote {
                    valueEnd += 1
                }
                guard valueEnd < raw.count else { break }

                let value = String(decoding: raw[valueStart..<valueEnd], as: UTF8.self)
                if let date = fractional.date(from: value) ?? whole.date(from: value) {
                    results.append(date)
                }
                index = valueEnd + 1
            }
        }
        return results
    }

    // MARK: - Filesystem

    private func recentLogs(in directory: URL, limit: Int, now: Date) -> [URL] {
        let cutoff = now.addingTimeInterval(-lookback)
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var candidates: [(url: URL, modified: Date)] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl",
                  let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  modified >= cutoff
            else { continue }
            candidates.append((url, modified))
        }

        return candidates
            .sorted { $0.modified > $1.modified }
            .prefix(limit)
            .map(\.url)
    }

    private func fileSize(of url: URL) -> UInt64? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize
        else { return nil }
        return UInt64(size)
    }

    private func readBytes(of url: URL, from offset: UInt64) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: offset)
            return try handle.readToEnd()
        } catch {
            return nil
        }
    }
}
