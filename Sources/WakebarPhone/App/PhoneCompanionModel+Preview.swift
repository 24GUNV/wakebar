import Foundation
import WakebarCore

extension PhoneCompanionModel {
    static var preview: PhoneCompanionModel {
        PhoneCompanionModel(
            client: UnavailablePhoneAlarmClient(reason: "Preview"),
            repository: UnavailablePhoneAlarmScheduleRepository(reason: "Preview"),
            payload: PhoneAlarmSchedulePayload(
                scheduleID: previewUUID("A19F7957-0D79-45C4-93BA-D16F68D2EFA7"),
                alarmID: previewUUID("A19F7957-0D79-45C4-93BA-D16F68D2EFA7"),
                revision: PhoneScheduleRevision(
                    sequence: 12,
                    modifiedAt: .now.addingTimeInterval(-120),
                    writerID: "preview-mac"
                ),
                isEnabled: true,
                title: "Wake up",
                hour: 7,
                minute: 0,
                weekdays: Weekday.workweek,
                followsDeviceTimeZone: true,
                sourceTimeZoneIdentifier: TimeZone.current.identifier
            )
        )
    }

    private static func previewUUID(_ value: String) -> UUID {
        guard let identifier = UUID(uuidString: value) else {
            fatalError("Invalid Wakebar preview UUID: \(value)")
        }
        return identifier
    }
}
