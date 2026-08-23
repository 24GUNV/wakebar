import Foundation

public actor ProviderDeliveryStore {
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? URL.applicationSupportDirectory
            .appending(path: "Wakebar", directoryHint: .isDirectory)
            .appending(path: "provider-delivery.json")
    }

    public func load(for revision: UUID) throws -> [ProviderID: ProviderDeliveryState] {
        let storedStates: [ProviderID: ProviderDeliveryState]
        if FileManager.default.fileExists(
            atPath: fileURL.path(percentEncoded: false)
        ) {
            storedStates = try JSONDecoder().decode(
                [ProviderID: ProviderDeliveryState].self,
                from: Data(contentsOf: fileURL)
            )
        } else {
            storedStates = [:]
        }

        return Dictionary(
            uniqueKeysWithValues: ProviderID.allCases.map { provider in
                if let state = storedStates[provider],
                   state.appliedRevision == revision,
                   state.phase == .confirmed
                {
                    return (provider, state)
                }
                return (provider, .draft(provider: provider, revision: revision))
            }
        )
    }

    public func save(_ states: [ProviderID: ProviderDeliveryState]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(states).write(to: fileURL, options: .atomic)
    }
}
