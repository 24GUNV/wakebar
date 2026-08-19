import WakebarCore

actor UITestPhoneAlarmInstallationStore: PhoneAlarmInstallationPersisting {
    private var installation: PhoneAlarmInstallation?

    func load() -> PhoneAlarmInstallation? {
        installation
    }

    func save(_ installation: PhoneAlarmInstallation) {
        self.installation = installation
    }

    func clear() {
        installation = nil
    }
}
