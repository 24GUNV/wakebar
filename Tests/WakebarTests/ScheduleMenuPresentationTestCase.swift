@testable import WakebarCore

struct ScheduleMenuPresentationTestCase {
    let name: String
    let isEnabled: Bool
    var hasSchedule: Bool = true
    let providersReady: Bool
    let alarmEnabled: Bool
    let phonePhase: PhoneAlarmMenuPhase
    let state: ScheduleMenuState
    let status: String
    let action: String
    let destination: ScheduleMenuDestination
}
