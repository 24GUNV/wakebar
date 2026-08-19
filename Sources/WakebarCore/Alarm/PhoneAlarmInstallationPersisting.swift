public protocol PhoneAlarmInstallationPersisting: Sendable {
    func load() async throws -> PhoneAlarmInstallation?
    func save(_ installation: PhoneAlarmInstallation) async throws
    func clear() async throws
}
