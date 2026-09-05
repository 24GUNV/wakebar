struct ClaudeRoutineSyncResult: Equatable, Sendable {
    let routineCount: Int
    let createdCount: Int
    let updatedCount: Int
    let deletedCount: Int

    var summary: String {
        let changeCount = createdCount + updatedCount + deletedCount
        if changeCount == 0 {
            return "Already up to date"
        }
        return "Created \(createdCount), updated \(updatedCount), deleted \(deletedCount)"
    }
}
