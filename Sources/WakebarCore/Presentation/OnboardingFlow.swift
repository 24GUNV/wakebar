/// Ordered walkthrough of first-run setup. Provider steps exist only for the services the schedule includes,
/// so the step list is derived rather than stored.
public struct OnboardingFlow: Equatable, Sendable {
    public private(set) var step: OnboardingStep
    public private(set) var providers: [ProviderID]

    public init(step: OnboardingStep = .welcome, providers: [ProviderID] = []) {
        self.step = step
        self.providers = providers
        anchorStep()
    }

    public var steps: [OnboardingStep] {
        [.welcome, .schedule] + providers.map(OnboardingStep.providerSetup) + [.done]
    }

    public var stepNumber: Int {
        (steps.firstIndex(of: step) ?? 0) + 1
    }

    public var stepCount: Int {
        steps.count
    }

    public var isFirstStep: Bool {
        step == steps.first
    }

    public var isLastStep: Bool {
        step == steps.last
    }

    /// The schedule step decides which provider steps follow, so providers are set as that step is left.
    public mutating func setProviders(_ providers: [ProviderID]) {
        self.providers = ProviderID.allCases.filter(providers.contains)
        anchorStep()
    }

    public mutating func advance() {
        guard let index = steps.firstIndex(of: step), index + 1 < steps.count else { return }
        step = steps[index + 1]
    }

    public mutating func retreat() {
        guard let index = steps.firstIndex(of: step), index > 0 else { return }
        step = steps[index - 1]
    }

    /// A provider step disappears when its service is switched off; the schedule step owns that choice.
    private mutating func anchorStep() {
        guard !steps.contains(step) else { return }
        step = .schedule
    }
}
