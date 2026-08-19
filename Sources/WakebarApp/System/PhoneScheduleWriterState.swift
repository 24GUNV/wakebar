import Foundation

struct PhoneScheduleWriterState: Codable, Sendable {
    let writerID: String
    let sequence: Int64
}
