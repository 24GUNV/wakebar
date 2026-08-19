import WakebarCore

@available(iOS 26.0, *)
@MainActor
enum PhoneCompanionRuntime {
    static let model = PhoneCompanionModel(
        client: AlarmKitPhoneAlarmClient(),
        repository: CloudKitPhoneAlarmScheduleRepository()
    )
}
