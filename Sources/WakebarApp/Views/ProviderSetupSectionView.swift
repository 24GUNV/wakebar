import SwiftUI

struct ProviderSetupSectionView: View {
    @Bindable var model: AppModel
    @Environment(\.openURL) private var openURL
    private let pasteboard = PasteboardService()

    var body: some View {
        Section("Provider setup") {
            if model.schedule.includeClaude {
                LabeledContent("Claude Code") {
                    Text(model.providerDeliveryStates[.claude]?.phase.displayName ?? "Draft")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Copy Routine setup", systemImage: "doc.on.doc", action: copyClaudeSetup)
                    Button("Open Claude Routines", systemImage: "arrow.up.right", action: openClaudeRoutines)
                }

                ProviderConfirmationButton(model: model, provider: .claude)
            }

            if model.schedule.includeCodex {
                LabeledContent("Codex") {
                    Text(model.schedule.codexRoute.displayName)
                        .foregroundStyle(.secondary)
                }

                Button("Copy Codex setup", systemImage: "doc.on.doc", action: copyCodexSetup)
                ProviderConfirmationButton(model: model, provider: .codex)
            }

            Text("After setup, confirm each provider schedule before Wakebar marks it ready. Pause or delete provider tasks in Claude or ChatGPT.")
                .foregroundStyle(.secondary)
        }
    }

    private func copyClaudeSetup() {
        do {
            let text = try model.claudeSetupInstructions()
            model.reportCopyResult(
                pasteboard.copy(text),
                successMessage: "Claude Routine setup copied."
            )
        } catch {
            model.reportCopyResult(false, successMessage: "")
        }
    }

    private func openClaudeRoutines() {
        guard let url = URL(string: "https://claude.ai/code/routines") else { return }
        openURL(url)
    }

    private func copyCodexSetup() {
        model.reportCopyResult(
            pasteboard.copy(model.codexSetupInstructions()),
            successMessage: "Codex setup copied."
        )
    }

}
