struct ClaudeEnvironment: Decodable, Equatable, Sendable {
    let id: String
    let kind: String

    private enum CodingKeys: String, CodingKey {
        case id = "environment_id"
        case kind
    }
}
