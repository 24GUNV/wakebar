import XCTest
@testable import WakebarCore

final class OnboardingLaunchDecisionTests: XCTestCase {
    func testFirstRunPresentsTheWalkthrough() {
        XCTAssertEqual(
            OnboardingLaunchDecision.resolve(hasSavedSchedule: false, hasPresentedThisLaunch: false),
            .present
        )
    }

    func testASavedScheduleSuppressesTheWalkthrough() {
        XCTAssertEqual(
            OnboardingLaunchDecision.resolve(hasSavedSchedule: true, hasPresentedThisLaunch: false),
            .skip
        )
    }

    func testTheWalkthroughIsPresentedOncePerLaunch() {
        XCTAssertEqual(
            OnboardingLaunchDecision.resolve(hasSavedSchedule: false, hasPresentedThisLaunch: true),
            .skip
        )
    }
}
