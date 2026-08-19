#if os(iOS) && canImport(AlarmKit)
import AlarmKit
import Foundation
import SwiftUI

@available(iOS 26.0, *)
public actor AlarmKitPhoneAlarmClient: PhoneAlarmClient {
    private let manager = AlarmManager.shared

    public init() {}

    public func authorizationState() async -> PhoneAlarmAuthorizationState {
        Self.authorizationState(from: manager.authorizationState)
    }

    public func requestAuthorization() async throws -> PhoneAlarmAuthorizationState {
        Self.authorizationState(from: try await manager.requestAuthorization())
    }

    public func schedule(_ payload: PhoneAlarmSchedulePayload) async throws {
        let payload = try payload.validated()
        let alarmTime = Alarm.Schedule.Relative.Time(hour: payload.hour, minute: payload.minute)
        let recurrence = Alarm.Schedule.Relative.Recurrence.weekly(
            payload.weekdays
                .sorted { $0.rawValue < $1.rawValue }
                .map(Self.localeWeekday)
        )
        let schedule = Alarm.Schedule.relative(.init(time: alarmTime, repeats: recurrence))
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(title: "Wakebar")
        } else {
            let stopButton = AlarmButton(
                text: "Stop",
                textColor: .white,
                systemImageName: "stop.circle.fill"
            )
            alert = AlarmPresentation.Alert(title: "Wakebar", stopButton: stopButton)
        }
        let metadata = WakebarAlarmMetadata(
            scheduleID: payload.scheduleID.uuidString,
            revisionSequence: payload.revision.sequence
        )
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: metadata,
            tintColor: .indigo
        )
        let configuration: AlarmManager.AlarmConfiguration<WakebarAlarmMetadata>
        if #available(iOS 26.1, *) {
            configuration = .alarm(schedule: schedule, attributes: attributes)
        } else {
            configuration = AlarmManager.AlarmConfiguration(
                schedule: schedule,
                attributes: attributes
            )
        }

        _ = try await manager.schedule(id: payload.alarmID, configuration: configuration)
    }

    public func cancel(alarmID: UUID) async throws {
        try manager.cancel(id: alarmID)
    }

    public func scheduledAlarmIDs() async throws -> Set<UUID> {
        Set(try manager.alarms.map(\.id))
    }

    public func alarmUpdates() async -> AsyncStream<Set<UUID>> {
        AsyncStream { continuation in
            let task = Task {
                for await alarms in manager.alarmUpdates {
                    continuation.yield(Set(alarms.map(\.id)))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func authorizationState(
        from state: AlarmManager.AuthorizationState
    ) -> PhoneAlarmAuthorizationState {
        switch state {
        case .notDetermined:
            .notDetermined
        case .authorized:
            .authorized
        case .denied:
            .denied
        @unknown default:
            .unavailable("This AlarmKit authorization state is not supported yet.")
        }
    }

    private static func localeWeekday(_ weekday: Weekday) -> Locale.Weekday {
        switch weekday {
        case .sunday: .sunday
        case .monday: .monday
        case .tuesday: .tuesday
        case .wednesday: .wednesday
        case .thursday: .thursday
        case .friday: .friday
        case .saturday: .saturday
        }
    }
}
#endif
