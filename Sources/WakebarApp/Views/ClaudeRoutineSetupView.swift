import SwiftUI
import WakebarCore

struct ClaudeRoutineSetupView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: WakebarDesign.sectionSpacing) {
            LabeledContent("Last sync") {
                WindowStatusValue(text: syncStatus, kind: syncStatusKind)
            }
            .help(syncHelp)

            LabeledContent("Routines", value: routineCount)

            if let expiry = model.claudeSetup.credentialExpiryText {
                LabeledContent("Credential", value: expiry)
            }

            if case let .failed(message) = model.claudeSetup.state {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: WakebarDesign.compactSpacing) {
                Button("Sync Routines", action: syncRoutines)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSyncing)

                Link("Verify on claude.ai", destination: routinesURL)
            }
        }
    }

    private var syncStatus: String {
        switch model.claudeSetup.state {
        case .idle:
            "Not synced"
        case .syncing:
            "Syncing…"
        case let .synced(at, _, _):
            at.formatted(date: .abbreviated, time: .shortened)
        case .failed:
            "Sync failed"
        }
    }

    private var syncStatusKind: ServiceStatusKind {
        switch model.claudeSetup.state {
        case .idle, .failed:
            .actionRequired
        case .syncing:
            .inProgress
        case .synced:
            .ready
        }
    }

    private var syncHelp: String {
        switch model.claudeSetup.state {
        case let .synced(_, _, summary):
            "\(summary). Syncing changes Routine schedules; it does not send a prompt."
        default:
            "Wakebar creates, updates, and disables only Routines with this schedule's Wakebar prefix."
        }
    }

    private var routineCount: String {
        switch model.claudeSetup.state {
        case let .synced(_, count, _):
            count.formatted()
        default:
            "—"
        }
    }

    private var isSyncing: Bool {
        model.claudeSetup.state == .syncing
    }

    private var routinesURL: URL {
        URL(string: "https://claude.ai/code/routines")
            ?? URL(filePath: "/")
    }

    private func syncRoutines() {
        Task {
            await model.syncClaudeRoutines()
        }
    }
}
