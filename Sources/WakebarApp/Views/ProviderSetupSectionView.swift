import SwiftUI
import WakebarCore

/// The provider sheet: a title, the state of the one thing being set up, and
/// the actions that change it, with the sheet's own buttons on a bottom bar
/// where macOS keeps them.
///
/// It used to open with an accent-coloured icon at title size and close with
/// two paragraphs of disclaimer. The disclaimers were facts about what Wakebar
/// can and cannot verify, so they now ride as tooltips on the controls they
/// qualify instead of as body copy.
struct ProviderSetupSectionView: View {
    @Bindable var model: AppModel
    let provider: ProviderID
    let purpose: ProviderSetupPurpose
    let onCleanupConfirmed: () -> Void
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    private let pasteboard = PasteboardService()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: WakebarDesign.sectionSpacing) {
                header

                if purpose == .cleanup {
                    cleanupControls
                } else {
                    setupControls
                }
            }
            .padding(WakebarDesign.windowPadding)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Divider()

            actionBar
                .padding(.horizontal, WakebarDesign.windowPadding)
                .padding(.vertical, 12)
        }
        .frame(width: WakebarDesign.sheetWidth)
        .frame(minHeight: WakebarDesign.sheetMinimumHeight)
        .interactiveDismissDisabled(purpose == .cleanup)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(headerTitle)
                .font(.headline)

            if model.providerIsExperimental(provider) {
                RowBadge(text: "Experimental")
                    .help("Wakebar has not verified that a Codex task refreshes the ChatGPT usage window.")
            }
        }
    }

    private var headerTitle: String {
        purpose == .cleanup ? "Remove \(provider.displayName)" : provider.displayName
    }

    /// What the provider holds in its own cloud, named the way the provider
    /// names it. It is the subject of every row and button on this sheet.
    private var hostedItemLabel: String {
        provider == .claude ? "Routine" : "Scheduled task"
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupControls: some View {
        if provider == .claude {
            ClaudeRoutineSetupView(model: model)
        } else {
            LabeledContent(hostedItemLabel) {
                WindowStatusValue(
                    text: model.providerMenuStatus(for: provider),
                    kind: model.providerMenuStatusKind(for: provider)
                )
            }

            HStack(spacing: WakebarDesign.compactSpacing) {
                Button("Copy Setup and Open ChatGPT", action: prepareCodexSetup)
                    .buttonStyle(.borderedProminent)

                if model.isProviderReady(provider) {
                    Button("Mark as Not Set Up", action: clearConfirmation)
                } else {
                    ProviderConfirmationButton(model: model, provider: provider)
                }
            }
        }
    }

    // MARK: - Cleanup

    private var cleanupControls: some View {
        VStack(alignment: .leading, spacing: WakebarDesign.sectionSpacing) {
            LabeledContent(hostedItemLabel) {
                WindowStatusValue(text: "Still running", kind: .actionRequired)
            }

            Text(cleanupCaveat)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(cleanupButtonTitle, action: openProvider)
        }
    }

    /// The one sentence on this sheet. It carries the fact the rows cannot: the
    /// removal happens in Wakebar, and the provider keeps running regardless.
    private var cleanupCaveat: String {
        provider == .claude
            ? "Wakebar cannot stop a Routine that already lives in Claude."
            : "Wakebar cannot stop a task that already lives in ChatGPT."
    }

    private var cleanupButtonTitle: String {
        provider == .claude ? "Open Claude Routines" : "Open ChatGPT Scheduled"
    }

    // MARK: - Sheet buttons

    private var actionBar: some View {
        HStack(spacing: WakebarDesign.compactSpacing) {
            Spacer(minLength: 0)

            if purpose == .cleanup {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("I've Removed It", action: onCleanupConfirmed)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .help("Wakebar saves the schedule change once you confirm this.")
            } else {
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - Actions

    private func openProvider() {
        let urlString = provider == .claude
            ? "https://claude.ai/code/routines"
            : "https://chatgpt.com/scheduled"
        if let url = URL(string: urlString) {
            openURL(url)
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
