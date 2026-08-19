import Foundation
import WakebarCore

actor MacPhoneSchedulePublisher {
    private let repository: any PhoneAlarmScheduleRepository
    private let revisionStore: PhoneScheduleRevisionStore

    init(
        repository: any PhoneAlarmScheduleRepository = CloudKitPhoneAlarmScheduleRepository(),
        revisionStore: PhoneScheduleRevisionStore = PhoneScheduleRevisionStore()
    ) {
        self.repository = repository
        self.revisionStore = revisionStore
    }

    func publish(_ schedule: WakeSchedule) async throws -> PhoneAlarmPublishReceipt {
        let revision = try await revisionStore.nextRevision()
        let payload = PhoneAlarmSchedulePayload(
            scheduleID: schedule.id,
            alarmID: schedule.id,
            revision: revision,
            isEnabled: schedule.isEnabled && schedule.alarmOnIPhone,
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
