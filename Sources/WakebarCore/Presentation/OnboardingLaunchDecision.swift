/// First run is the absence of a persisted schedule, so no separate onboarding flag is stored.
public enum OnboardingLaunchDecision: Equatable, Sendable {
    case present
    case skip

    public static func resolve(hasSavedSchedule: Bool, hasPresentedThisLaunch: Bool) -> Self {
        hasSavedSchedule || hasPresentedThisLaunch ? .skip : .present
    }
}
