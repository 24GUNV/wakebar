import SwiftUI
import WakebarCore

struct ProviderSetupSectionView: View {
    @Bindable var model: AppModel
    let provider: ProviderID
    let purpose: ProviderSetupPurpose
    let onCleanupConfirmed: () -> Void
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    private let pasteboard = PasteboardService()

    var body: some View {
        VStack(alignment: .leading, spacing: WakebarDesign.sectionSpacing) {
            HStack {
                Image(systemName: provider.systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)

                Text(setupTitle)
                    .font(.title2)
                    .bold()

                Spacer()

                Button(purpose == .cleanup ? "Cancel" : "Done") {
                    dismiss()
                }
            }

            Text(setupHelpText)
                .foregroundStyle(.secondary)

            Divider()

            if purpose == .cleanup {
                cleanupControls
            } else {
                setupControls
            }

            Spacer(minLength: 0)

            Text(footerText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(WakebarDesign.horizontalPadding)
        .frame(width: 440)
        .frame(minHeight: 310)
        .interactiveDismissDisabled(purpose == .cleanup)
    }

    private var setupTitle: String {
        if purpose == .cleanup {
            return provider == .claude ? "Remove Claude Code" : "Remove experimental Codex"
        }
        return provider == .claude ? "Claude Code setup" : "Experimental Codex setup"
    }

    @ViewBuilder
    private var setupControls: some View {
        if model.isProviderReady(provider) {
            Label(confirmedStatusText, systemImage: confirmedStatusImage)
                .foregroundStyle(provider == .codex ? .orange : .secondary)
        } else {
            Label("One-time setup required", systemImage: "exclamationmark.circle")
                .foregroundStyle(.orange)
        }

        Button(setupButtonTitle, systemImage: "arrow.up.forward.app", action: prepareSetup)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        if model.isProviderReady(provider) {
            Button("Mark as not set up", action: clearConfirmation)
        } else {
            HStack {
                ProviderConfirmationButton(model: model, provider: provider)
                Text("after you review and save it in the provider")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var cleanupControls: some View {
        VStack(alignment: .leading, spacing: WakebarDesign.sectionSpacing) {
            Label("Hosted task may still be active", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Button(cleanupButtonTitle, systemImage: "arrow.up.forward.app", action: openProvider)
                .controlSize(.large)

            Button("I've paused or deleted it") {
                onCleanupConfirmed()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var setupButtonTitle: String {
        switch provider {
        case .claude:
            "Copy setup and open Routines"
        case .codex:
            "Copy setup and open ChatGPT"
        }
    }

    private var confirmedStatusText: String {
        provider == .codex
            ? "Marked as set up by you · effect unverified"
            : "Marked as set up by you"
    }

    private var confirmedStatusImage: String {
        provider == .codex ? "flask.fill" : "checkmark.circle.fill"
    }

    private var footerText: String {
        if purpose == .cleanup {
            return "Wakebar keeps the current schedule until you acknowledge that the hosted task is paused or deleted."
        }
        return "Wakebar does not receive independent proof that a provider task exists. This status records your confirmation."
    }

    private var setupHelpText: String {
        if purpose == .cleanup {
            return provider == .claude
                ? "Removing Claude Code from Wakebar does not stop its existing Routine. Pause or delete it in Claude before Wakebar saves this change."
                : "Removing Codex from Wakebar does not stop its experimental ChatGPT task. Pause or delete it in ChatGPT before Wakebar saves this change."
        }
        switch provider {
        case .claude:
            return "Wakebar prepares the details; Anthropic requires you to review and save the Routine once."
        case .codex:
            return "OpenAI requires you to create the task, and its usage-window effect is unverified."
        }
    }

    private func prepareSetup() {
        switch provider {
        case .claude:
            prepareClaudeSetup()
        case .codex:
            prepareCodexSetup()
        }
    }

    private var cleanupButtonTitle: String {
        provider == .claude ? "Open Claude Routines" : "Open ChatGPT Scheduled"
    }

    private func openProvider() {
        let urlString = provider == .claude
            ? "https://claude.ai/code/routines"
            : "https://chatgpt.com/scheduled"
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }

    private func prepareClaudeSetup() {
        let didCopy = pasteboard.copy(model.claudeSetupInstructions())
        model.reportCopyResult(
            didCopy,
            successMessage: "Routine details copied. Use them to fill the Routines form."
        )
        if didCopy, let routinesURL = URL(string: "https://claude.ai/code/routines") {
            openURL(routinesURL)
        }
    }

    private func prepareCodexSetup() {
        let didCopy = pasteboard.copy(model.codexSetupInstructions())
        model.reportCopyResult(
            didCopy,
            successMessage: "ChatGPT task copied. Paste it once in Scheduled."
        )
        if didCopy, let scheduledURL = URL(string: "https://chatgpt.com/scheduled") {
            openURL(scheduledURL)
        }
    }

    private func clearConfirmation() {
        model.clearProviderConfirmation(provider)
    }
}
