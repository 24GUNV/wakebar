import Foundation
import WakebarCore

actor PhoneScheduleRevisionStore {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.applicationSupportDirectory
            .appending(path: "Wakebar", directoryHint: .isDirectory)
            .appending(path: "phone-writer-state.json")
    }

    func nextRevision() throws -> PhoneScheduleRevision {
        let previousState = try load()
        let writerID = previousState?.writerID ?? UUID().uuidString.lowercased()
        let state = PhoneScheduleWriterState(
            writerID: writerID,
            sequence: (previousState?.sequence ?? 0) + 1
        )
        try save(state)
        return PhoneScheduleRevision(
            sequence: state.sequence,
            modifiedAt: .now,
            writerID: state.writerID
        )
    }

    private func load() throws -> PhoneScheduleWriterState? {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return nil }
        return try JSONDecoder().decode(
            PhoneScheduleWriterState.self,
            from: Data(contentsOf: fileURL)
        )
    }

    private func save(_ state: PhoneScheduleWriterState) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(state).write(to: fileURL, options: .atomic)
    }
}
