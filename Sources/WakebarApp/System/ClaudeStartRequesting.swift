import WakebarCore

protocol ClaudeStartRequesting: Sendable {
    func requestStart(for schedule: WakeSchedule) async throws
}
