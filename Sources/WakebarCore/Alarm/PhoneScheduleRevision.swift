import Foundation

public struct PhoneScheduleRevision: Codable, Equatable, Sendable {
    public let sequence: Int64
    public let modifiedAt: Date
    public let writerID: String

    public init(sequence: Int64, modifiedAt: Date, writerID: String) {
        self.sequence = sequence
        let milliseconds = (modifiedAt.timeIntervalSince1970 * 1_000).rounded()
        self.modifiedAt = Date(timeIntervalSince1970: milliseconds / 1_000)
        self.writerID = writerID
    }

    private enum CodingKeys: String, CodingKey {
        case sequence
        case modifiedAt
        case writerID
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sequence: try container.decode(Int64.self, forKey: .sequence),
            modifiedAt: try container.decode(Date.self, forKey: .modifiedAt),
            writerID: try container.decode(String.self, forKey: .writerID)
        )
    }

    public func isNewer(than other: Self) -> Bool {
        if sequence != other.sequence {
            return sequence > other.sequence
        }

        if modifiedAt != other.modifiedAt {
            return modifiedAt > other.modifiedAt
        }

        return writerID > other.writerID
    }
}
