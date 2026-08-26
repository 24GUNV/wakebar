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
    /// The onboarding wizard embeds this view inside its own window chrome and
    /// navigation; standalone it is a fixed-width sheet with its own Done.
    var isEmbedded = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: WakebarDesign.sectionSpacing) {
                header

                setupControls
            }
            .padding(WakebarDesign.windowPadding)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            if !isEmbedded {
                Divider()

                actionBar
                    .padding(.horizontal, WakebarDesign.windowPadding)
                    .padding(.vertical, 12)
            }
        }
        .frame(width: isEmbedded ? nil : WakebarDesign.sheetWidth)
        .frame(minHeight: WakebarDesign.sheetMinimumHeight)
    }

    private var header: some View {
        Text(headerTitle)
            .font(.headline)
    }

    private var headerTitle: String {
        provider.displayName
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupControls: some View {
        if provider == .claude {
            ClaudeRoutineSetupView(model: model)
        } else {
            CodexTaskSetupView(model: model)
        }
    }

    // MARK: - Sheet buttons

    private var actionBar: some View {
        HStack(spacing: WakebarDesign.compactSpacing) {
            Spacer(minLength: 0)

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }

}
