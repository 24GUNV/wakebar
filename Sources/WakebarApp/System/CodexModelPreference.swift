import Foundation

/// The model the user's own Codex CLI is set to, read from `config.toml`.
///
/// A wake has to land on the limit the user actually works against. Codex
/// meters some models separately — a request to one of those opens a window
/// nobody is waiting for — so the wake goes to the model the CLI would use.
struct CodexModelPreference: Sendable {
    /// What Codex CLI itself defaults to when the file names nothing.
    static let fallbackModel = "gpt-5.6-sol"

    private let environment: [String: String]
    private let homeDirectory: URL

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.environment = environment
        self.homeDirectory = homeDirectory
    }

    var model: String {
        let configURL = codexHome.appendingPathComponent("config.toml")
        guard let contents = try? String(contentsOf: configURL, encoding: .utf8) else {
            return Self.fallbackModel
        }
        return Self.topLevelModel(in: contents) ?? Self.fallbackModel
    }

    /// The top-level `model = "…"` line. Anything after the first `[table]`
    /// header belongs to a profile or provider and is not the default.
    static func topLevelModel(in toml: String) -> String? {
        for rawLine in toml.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") { return nil }
            guard line.hasPrefix("model") else { continue }
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2,
                  parts[0].trimmingCharacters(in: .whitespaces) == "model"
            else { continue }
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            let unquoted = value.split(separator: "#", maxSplits: 1)[0]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return unquoted.isEmpty ? nil : unquoted
        }
        return nil
    }

    private var codexHome: URL {
        if let override = environment["CODEX_HOME"], !override.isEmpty {
            return URL(filePath: override)
        }
        return homeDirectory.appendingPathComponent(".codex")
    }
}
