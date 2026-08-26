import SwiftUI
import WakebarCore

/// Guided setup. It owns no setup logic of its own: each step drives the same
/// model calls the settings window uses, and the provider step embeds the
/// shared provider setup view.
struct OnboardingView: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WakeSchedule

    init(model: AppModel) {
        self.model = model
        _draft = State(initialValue: model.schedule)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                stepContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let activityNotice = model.activityNotice {
                ActivityStripView(notice: activityNotice)
            }

            navigationBar
        }
        .frame(width: 460, height: 500)
        .onAppear {
            NSApplication.shared.activate()
        }
        .task {
            await model.load()
            draft = model.schedule
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.onboardingFlow.step {
        case .welcome:
            OnboardingWelcomeStepView()
                .padding(WakebarDesign.windowPadding)
        case .schedule:
            OnboardingScheduleStepView(draft: $draft)
                .padding(WakebarDesign.windowPadding)
        case let .providerSetup(provider):
            ProviderSetupSectionView(
                model: model,
                provider: provider,
                isEmbedded: true
            )
        case .done:
            OnboardingSummaryStepView(model: model)
                .padding(WakebarDesign.windowPadding)
        }
    }

    private var navigationBar: some View {
        HStack(spacing: WakebarDesign.sectionSpacing) {
            Text("Step \(model.onboardingFlow.stepNumber) of \(model.onboardingFlow.stepCount)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()

            if !model.onboardingFlow.isFirstStep {
                Button("Back", action: model.retreatOnboarding)
                    .controlSize(.large)
            }

            Button(continueTitle, action: continueFromStep)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(!canContinue)
        }
        .padding(.horizontal, WakebarDesign.windowPadding)
        .padding(.vertical, WakebarDesign.compactSpacing)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var continueTitle: String {
        switch model.onboardingFlow.step {
        case .welcome:
            "Get Started"
        case .schedule:
            "Save & Continue"
        case let .providerSetup(provider):
            // Never blocks on the provider: an unfinished service reads as a
            // skip, and the summary step says so instead of overstating.
            model.isProviderReady(provider) ? "Continue" : "Skip for Now"
        case .done:
            "Done"
        }
    }

    private var canContinue: Bool {
        guard model.onboardingFlow.step == .schedule else { return true }
        return draft.isValid
    }

    private func continueFromStep() {
        switch model.onboardingFlow.step {
        case .schedule:
            model.completeOnboardingScheduleStep(with: draft)
            draft = model.schedule
        case .done:
            dismiss()
        case .welcome, .providerSetup:
            model.advanceOnboarding()
        }
    }
}
