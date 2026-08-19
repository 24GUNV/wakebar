@testable import WakebarCore

actor TestPhoneAlarmInstallationStore: PhoneAlarmInstallationPersisting {
    private var installation: PhoneAlarmInstallation?
    private var saveAttemptCount = 0
    private var failingSaveAttempts: Set<Int> = []

    func load() async throws -> PhoneAlarmInstallation? {
        installation
    }

    func save(_ installation: PhoneAlarmInstallation) async throws {
        saveAttemptCount += 1
        if failingSaveAttempts.remove(saveAttemptCount) != nil {
            throw TestPhoneAlarmInstallationStoreError.saveFailed
        }
        self.installation = installation
    }

    func clear() async throws {
        installation = nil
    }

    func failNextSave() {
        failingSaveAttempts.insert(saveAttemptCount + 1)
    }

    func failSave(onAdditionalAttempts attempts: Set<Int>) {
        failingSaveAttempts.formUnion(attempts.map { saveAttemptCount + $0 })
    }
}
