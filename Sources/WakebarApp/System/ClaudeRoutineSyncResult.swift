struct ClaudeRoutineSyncResult: Equatable, Sendable {
    let routineCount: Int
    let createdCount: Int
    let updatedCount: Int
    let disabledCount: Int

    var summary: String {
        let changeCount = createdCount + updatedCount + disabledCount
        if changeCount == 0 {
            return "Already up to date"
        }
        return "Created \(createdCount), updated \(updatedCount), disabled \(disabledCount)"
    }
}
