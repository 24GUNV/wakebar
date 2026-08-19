import Foundation

public actor PhoneAlarmPayloadStore {
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.applicationSupportDirectory
            .appending(path: "Wakebar", directoryHint: .isDirectory)
            .appending(path: "phone-schedule-cache.json")
    }

    public func load() throws -> CachedPhoneAlarmSchedule? {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(CachedPhoneAlarmSchedule.self, from: data)
    }

    public func save(_ cachedSchedule: CachedPhoneAlarmSchedule) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(cachedSchedule).write(to: fileURL, options: .atomic)
    }

    public func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
