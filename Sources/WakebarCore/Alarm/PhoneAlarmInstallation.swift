import Foundation

public struct PhoneAlarmInstallation: Codable, Equatable, Sendable {
    public let payload: PhoneAlarmSchedulePayload
    public let installedAt: Date
    public let managedAlarmIDs: Set<UUID>
    public let requiresReconciliation: Bool
    public let recoveryPayload: PhoneAlarmSchedulePayload?

    public var alarmID: UUID { payload.alarmID }
    public var revision: PhoneScheduleRevision { payload.revision }

    public init(
        payload: PhoneAlarmSchedulePayload,
        installedAt: Date,
        managedAlarmIDs: Set<UUID>? = nil,
        requiresReconciliation: Bool = false,
        recoveryPayload: PhoneAlarmSchedulePayload? = nil
    ) {
        self.payload = payload
        self.installedAt = installedAt
        self.managedAlarmIDs = managedAlarmIDs ?? [payload.alarmID]
        self.requiresReconciliation = requiresReconciliation
        self.recoveryPayload = recoveryPayload
    }

    private enum CodingKeys: String, CodingKey {
        case payload
        case installedAt
        case managedAlarmIDs
        case requiresReconciliation
        case recoveryPayload
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        payload = try container.decode(PhoneAlarmSchedulePayload.self, forKey: .payload)
        installedAt = try container.decode(Date.self, forKey: .installedAt)
        managedAlarmIDs = try container.decodeIfPresent(
            Set<UUID>.self,
            forKey: .managedAlarmIDs
        ) ?? [payload.alarmID]
        requiresReconciliation = try container.decodeIfPresent(
            Bool.self,
            forKey: .requiresReconciliation
        ) ?? false
        recoveryPayload = try container.decodeIfPresent(
            PhoneAlarmSchedulePayload.self,
            forKey: .recoveryPayload
        )
    }
}
