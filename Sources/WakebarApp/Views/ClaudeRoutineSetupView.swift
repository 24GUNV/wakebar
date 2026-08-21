import SwiftUI
import WakebarCore

/// Claude Code setup, told as facts and one action rather than as nine
/// sentences each wearing its own icon.
///
/// Two rows carry the whole state — whether the command line on this Mac can
/// create a Routine, and whether a Routine has been saved — and the buttons
/// underneath are whatever moves that along next. Extra rows appear only when
/// there is a second fact worth naming, such as which version is installed.
struct ClaudeRoutineSetupView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: WakebarDesign.sectionSpacing) {
            VStack(alignment: .leading, spacing: 7) {
                LabeledContent("Command line") {
                    WindowStatusValue(text: commandLineStatus, kind: commandLineStatusKind)
                }
                .help(commandLineHelp)

                detailRows

                LabeledContent("Routine") {
                    WindowStatusValue(
                        text: model.providerMenuStatus(for: .claude),
                        kind: model.providerMenuStatusKind(for: .claude)
                    )
                }
            }

            if case let .failed(message) = model.claudeSetup.state {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actions
        }
    }

    // MARK: - State

    /// The popover's vocabulary wherever the situation is the same one, and a
    /// plain state word — never a sentence — wherever it is not.
    private var commandLineStatus: String {
        switch model.claudeSetup.state {
        case .checking:
            "Checking…"
        case .notFound:
            "Not installed"
        case .updateRequired:
            "Update required"
        case .signInRequired:
            "Sign-in required"
        case .unsupportedAuthentication:
            "Wrong sign-in"
        case .ready:
            "Ready"
        case .launching:
            "Opening…"
        case .launched:
            "Waiting for Terminal"
        case .failed:
            "Setup failed"
        }
    }

    private var commandLineStatusKind: ServiceStatusKind {
        switch model.claudeSetup.state {
        case .ready:
            .ready
        case .checking, .launching, .launched:
            .inProgress
        case .notFound, .updateRequired, .signInRequired, .unsupportedAuthentication, .failed:
            .actionRequired
        }
    }

    private var installedVersion: String? {
        switch model.claudeSetup.state {
        case let .ready(version):
            version
        case let .signInRequired(version):
            version
        case let .unsupportedAuthentication(version, _):
            version
        default:
            nil
        }
    }

    private var commandLineHelp: String {
        if let installedVersion {
            return "Claude Code \(installedVersion) on this Mac."
        }
        return "Wakebar creates the Routine by running Claude Code on this Mac."
    }

    /// A version mismatch is two numbers, not a sentence about two numbers.
    @ViewBuilder
    private var detailRows: some View {
        switch model.claudeSetup.state {
        case let .updateRequired(installed, required):
            LabeledContent("Installed", value: installed)
            LabeledContent("Required", value: required)
        case let .unsupportedAuthentication(_, method):
            LabeledContent("Signed in with", value: method)
        default:
            EmptyView()
        }
    }

    private var isWorking: Bool {
        switch model.claudeSetup.state {
        case .checking, .launching:
            true
        default:
            false
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        if isWorking {
            ProgressView()
                .controlSize(.small)
        } else {
            HStack(spacing: WakebarDesign.compactSpacing) {
                actionButtons
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch model.claudeSetup.state {
        case .checking, .launching:
            EmptyView()
        case .notFound:
            primaryButton("Install Claude Code", action: openInstallGuide)
            checkAgainButton
        case .updateRequired:
            primaryButton("Update Claude Code", action: updateClaudeCode)
            checkAgainButton
        case .signInRequired:
            primaryButton("Sign In to Claude Code", action: signInToClaudeCode)
            checkAgainButton
        case .unsupportedAuthentication:
            primaryButton("Use Claude.ai Sign-In", action: signInToClaudeCode)
            checkAgainButton
        case .ready:
            primaryButton(
                model.isProviderReady(.claude) ? "Update Routine" : "Create Routine",
                action: launchClaudeSetup
            )
            if model.isProviderReady(.claude) {
                Button("Mark as Not Set Up") {
                    model.clearProviderConfirmation(.claude)
                }
            }
        case .launched:
            primaryButton("Routine Saved in Claude", action: confirmRoutine)
            Button("Open Setup Again", action: launchClaudeSetup)
        case .failed:
            checkAgainButton
            Button("Open Claude Routines", action: openRoutinesPage)
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
    }

    private var checkAgainButton: some View {
        Button("Check Again", action: refreshClaudeCode)
    }

    private func launchClaudeSetup() {
        Task {
            await model.claudeSetup.startRoutineSetup(for: model.schedule)
        }
    }

    private func updateClaudeCode() {
        Task {
            await model.claudeSetup.updateClaudeCode()
        }
    }

    private func refreshClaudeCode() {
        Task {
            await model.claudeSetup.refresh()
        }
    }

    private func signInToClaudeCode() {
        Task {
            await model.claudeSetup.signIn()
        }
    }

    private func confirmRoutine() {
        model.confirmProviderSchedule(.claude)
        dismiss()
    }

    private func openInstallGuide() {
        guard let url = URL(string: "https://code.claude.com/docs/en/setup") else { return }
        openURL(url)
    }

    private func openRoutinesPage() {
        guard let url = URL(string: "https://claude.ai/code/routines") else { return }
        openURL(url)
    }
}
