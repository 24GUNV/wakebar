import Foundation
import WakebarCore

actor MacPhoneSchedulePublisher {
    private let repository: any PhoneAlarmScheduleRepository
    private let revisionStore: PhoneScheduleRevisionStore

    init(
        repository: (any PhoneAlarmScheduleRepository)? = nil,
        revisionStore: PhoneScheduleRevisionStore = PhoneScheduleRevisionStore()
    ) {
        self.repository = repository ?? Self.defaultRepository()
        self.revisionStore = revisionStore
    }

    private static func defaultRepository() -> any PhoneAlarmScheduleRepository {
#if DEBUG
        if ProcessInfo.processInfo.environment["WAKEBAR_DISABLE_CLOUDKIT"] == "1" {
            return UnavailablePhoneAlarmScheduleRepository(
                reason: "Phone sync is unavailable in local UI review mode."
            )
        }
#endif
        return CloudKitPhoneAlarmScheduleRepository()
    }

    func publish(_ schedule: WakeSchedule) async throws -> PhoneAlarmPublishReceipt {
        let revision = try await revisionStore.nextRevision()
        let payload = PhoneAlarmSchedulePayload(
            scheduleID: schedule.id,
            alarmID: schedule.id,
            revision: revision,
            isEnabled: schedule.isEnabled && schedule.isValid && schedule.alarmOnIPhone,
            title: "Wakebar",
            hour: schedule.hour,
            minute: schedule.minute,
            weekdays: schedule.selectedWeekdays,
            followsDeviceTimeZone: schedule.followsSystemTimeZone,
            sourceTimeZoneIdentifier: schedule.timeZoneIdentifier
        )

        try await repository.publish(payload)
        return PhoneAlarmPublishReceipt(
            scheduleID: schedule.id,
            revision: revision,
            publishedAt: .now
        )
    }

    func acknowledgement(for scheduleID: UUID) async throws -> PhoneAlarmAcknowledgement? {
        try await repository.acknowledgement(for: scheduleID)
    }
}
