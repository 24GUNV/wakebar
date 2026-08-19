import Foundation
import WakebarCore

@available(iOS 26.0, *)
@MainActor
enum PhoneCompanionRuntime {
    static let isUITesting = ProcessInfo.processInfo.arguments.contains("-wakebar-ui-testing")

    static let model: PhoneCompanionModel = {
        if isUITesting {
            PhoneCompanionModel(
                client: UnavailablePhoneAlarmClient(reason: "Safe UI test mode"),
                repository: UITestPhoneAlarmScheduleRepository(),
                installationStore: UITestPhoneAlarmInstallationStore()
            )
        } else {
            PhoneCompanionModel(
                client: AlarmKitPhoneAlarmClient(),
                repository: CloudKitPhoneAlarmScheduleRepository()
            )
        }
    }()
}
