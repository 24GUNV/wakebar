public enum OnboardingStep: Hashable, Sendable {
    case welcome
    case schedule
    case providerSetup(ProviderID)
    case done
}
