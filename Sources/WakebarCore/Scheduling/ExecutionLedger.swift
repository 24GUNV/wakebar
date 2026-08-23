import Foundation

public actor ExecutionLedger {
    private let fileURL: URL
    private var records: [String: ExecutionRecord]?

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
    }

    public func claim(eventID: String, at date: Date = .now) throws -> Bool {
        var loadedRecords = try loadIfNeeded()
        guard loadedRecords[eventID] == nil else { return false }

        loadedRecords[eventID] = ExecutionRecord(eventID: eventID, state: .claimed, updatedAt: date)
        try save(loadedRecords)
        records = loadedRecords
        return true
    }

    public func contains(eventID: String) throws -> Bool {
        try loadIfNeeded()[eventID] != nil
    }

    public func record(for eventID: String) throws -> ExecutionRecord? {
        try loadIfNeeded()[eventID]
    }

    public func markConfirmed(eventID: String, at date: Date = .now) throws {
        try update(eventID: eventID, state: .confirmed, at: date)
    }

    public func markFailedBeforeSend(eventID: String, at date: Date = .now) throws {
        try update(eventID: eventID, state: .failedBeforeSend, at: date)
    }

    public func markDeliveryUnknown(eventID: String, at date: Date = .now) throws {
        try update(eventID: eventID, state: .deliveryUnknown, at: date)
    }

    public func resetFailedBeforeSendForRetry(eventID: String) throws -> Bool {
        var loadedRecords = try loadIfNeeded()
        guard loadedRecords[eventID]?.state == .failedBeforeSend else { return false }

        loadedRecords.removeValue(forKey: eventID)
        try save(loadedRecords)
        records = loadedRecords
        return true
    }

    public func removeRecords(before cutoff: Date) throws {
        let retainedRecords = try loadIfNeeded().filter { _, record in
            record.updatedAt >= cutoff
        }

        try save(retainedRecords)
        records = retainedRecords
    }

    private func loadIfNeeded() throws -> [String: ExecutionRecord] {
        if let records {
            return records
        }

        guard FileManager.default.fileExists(
            atPath: fileURL.path(percentEncoded: false)
        ) else {
            records = [:]
            return [:]
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        let loadedRecords: [String: ExecutionRecord]
        if let currentRecords = try? decoder.decode([String: ExecutionRecord].self, from: data) {
            loadedRecords = currentRecords
        } else {
            let legacyRecords = try decoder.decode([String: Date].self, from: data)
            loadedRecords = Dictionary(
                uniqueKeysWithValues: legacyRecords.map { eventID, date in
                    (
                        eventID,
                        ExecutionRecord(eventID: eventID, state: .confirmed, updatedAt: date)
                    )
                }
            )
        }
        records = loadedRecords
        return loadedRecords
    }

    private func save(_ records: [String: ExecutionRecord]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(records).write(to: fileURL, options: .atomic)
    }

    private func update(eventID: String, state: ExecutionDeliveryState, at date: Date) throws {
        var loadedRecords = try loadIfNeeded()
        guard loadedRecords[eventID] != nil else {
            throw ExecutionLedgerError.missingClaim
        }

        loadedRecords[eventID] = ExecutionRecord(eventID: eventID, state: state, updatedAt: date)
        try save(loadedRecords)
        records = loadedRecords
    }

    private static var defaultFileURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "Wakebar", directoryHint: .isDirectory)
            .appending(path: "execution-ledger.json")
    }
}
