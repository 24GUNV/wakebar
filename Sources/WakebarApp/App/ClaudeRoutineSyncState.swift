import Foundation

enum ClaudeRoutineSyncState: Equatable {
    case idle
    case syncing
    case synced(at: Date, routineCount: Int, summary: String)
    case failed(String)
}
