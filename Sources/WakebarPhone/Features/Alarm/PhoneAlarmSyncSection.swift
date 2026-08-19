import SwiftUI
import WakebarCore

struct PhoneAlarmSyncSection: View {
    let model: PhoneCompanionModel
    let payload: PhoneAlarmSchedulePayload

    var body: some View {
        Section("Schedule source") {
            LabeledContent("From", value: "Wakebar on Mac")
            LabeledContent("iCloud", value: deliveryLabel)
            LabeledContent("Background updates", value: subscriptionLabel)
            LabeledContent("Updated") {
                Text(payload.revision.modifiedAt, format: .relative(presentation: .named))
            }
            LabeledContent("Time zone", value: "This iPhone")
            if model.acknowledgementError != nil {
                Label("Mac confirmation pending", systemImage: "icloud.slash")
                    .foregroundStyle(.secondary)
            }
            if let deliveryIssue {
                Text(deliveryIssue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let subscriptionIssue {
                Text(subscriptionIssue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text(footerText)
        }
    }

    private var deliveryLabel: String {
        switch model.deliveryState {
        case .neverChecked: "Not checked"
        case .noSchedule: "No schedule"
        case .current: "Up to date"
        case .stale: "Saved copy"
        case .accountChanged: "Account changed"
        case .unavailable: "Unavailable"
        }
    }

    private var subscriptionLabel: String {
        switch model.subscriptionState {
        case .notInstalled: "Not registered"
        case .installed: "Registered"
        case .unavailable: "Unavailable"
        }
    }

    private var deliveryIssue: String? {
        switch model.deliveryState {
        case let .stale(_, _, reason),
             let .accountChanged(reason, _),
             let .unavailable(reason, _):
            reason
        case .neverChecked, .noSchedule, .current:
            nil
        }
    }

    private var subscriptionIssue: String? {
        if case let .unavailable(reason) = model.subscriptionState {
            reason
        } else {
            nil
        }
    }

    private var footerText: String {
        if model.status == .armed {
            "AlarmKit accepted this schedule on this iPhone. iCloud updates can still be delayed."
        } else {
            "iCloud updates can be delayed. This schedule is not confirmed with AlarmKit yet."
        }
    }
}
