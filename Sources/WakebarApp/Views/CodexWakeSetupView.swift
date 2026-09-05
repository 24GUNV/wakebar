import SwiftUI
import WakebarCore

struct CodexWakeSetupView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: WakebarDesign.sectionSpacing) {
            if !model.isProviderConnected(.codex) {
                Text("Connect to let Wakebar read your Codex CLI login, check usage, and send short prompts on your enabled schedule. These requests consume subscription usage.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Connect Codex") {
                    Task { await model.connectProvider(.codex) }
                }
                .buttonStyle(.borderedProminent)
            }
            Text("Wakebar sends Codex a one-word request from this Mac at the scheduled time, or just after Codex's own limit resets on the every-reset cadence. It runs only while Wakebar is open. A wake missed while the Mac slept is sent as soon as it is back, unless you have already used Codex by then.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LabeledContent("Sign-in") {
                WindowStatusValue(text: signInStatus, kind: signInKind)
            }
            .help("Wakebar reads the Codex CLI credential from ~/.codex and sends it only to chatgpt.com.")

            LabeledContent("Last wake") {
                WindowStatusValue(text: wakeStatus, kind: wakeStatusKind)
            }
            .help("Window started appears only after Codex reports the new window.")

            if let nextCheck = model.codexWake.nextCheckAt {
                LabeledContent("Next check", value: nextCheck.formatted(date: .abbreviated, time: .shortened))
            }

            if case let .failed(message, _) = model.codexWake.state {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Send now") { model.startNow(.codex) }
                .buttonStyle(.borderedProminent)
                .disabled(model.providerStartNowStates[.codex] == .requested || !model.codexWake.isSignedIn)
        }
    }

    private var signInStatus: String {
        model.codexWake.isSignedIn
            ? "Codex CLI"
            : UsageWindowProviderIssue.missingCredentials.message(for: .codex)
    }

    private var signInKind: ServiceStatusKind {
        model.codexWake.isSignedIn ? .ready : .actionRequired
    }

    private var wakeStatus: String {
        switch model.codexWake.state {
        case .idle:
            return "None yet"
        case .sending:
            return "Sending…"
        case let .sent(at):
            return "Sent \(at.formatted(date: .abbreviated, time: .shortened)); not confirmed"
        case let .confirmed(window, _):
            let start = window.resetsAt.addingTimeInterval(-window.duration)
            return (window.isSessionWindow ? "Window started " : "Week started ")
                + start.formatted(date: .abbreviated, time: .shortened)
        case let .failed(_, at):
            return "Failed \(at.formatted(date: .abbreviated, time: .shortened))"
        }
    }

    private var wakeStatusKind: ServiceStatusKind {
        switch model.codexWake.state {
        case .idle, .sending, .sent:
            .inProgress
        case .confirmed:
            .ready
        case .failed:
            .actionRequired
        }
    }
}
