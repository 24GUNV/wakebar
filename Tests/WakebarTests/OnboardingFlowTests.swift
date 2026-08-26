import XCTest
@testable import WakebarCore

final class OnboardingFlowTests: XCTestCase {
    func testStepsCoverEverySelectedProvider() {
        let flow = OnboardingFlow(providers: [.claude, .codex])

        XCTAssertEqual(
            flow.steps,
            [.welcome, .schedule, .providerSetup(.claude), .providerSetup(.codex), .done]
        )
    }

    func testStepsSkipProvidersTheScheduleExcludes() {
        let flow = OnboardingFlow(providers: [.codex])

        XCTAssertEqual(flow.steps, [.welcome, .schedule, .providerSetup(.codex), .done])
    }

    func testProvidersFollowTheStableProviderOrder() {
        var flow = OnboardingFlow()
        flow.setProviders([.codex, .claude])

        XCTAssertEqual(flow.providers, [.claude, .codex])
    }

    func testAdvanceVisitsEveryStepOnce() {
        var flow = OnboardingFlow(providers: [.claude, .codex])
        var visited: [OnboardingStep] = [flow.step]

        for _ in 1..<flow.stepCount {
            flow.advance()
            visited.append(flow.step)
        }

        XCTAssertEqual(visited, flow.steps)
    }

    func testAdvanceStopsAtTheFinalStep() {
        var flow = OnboardingFlow(step: .done, providers: [.claude])
        flow.advance()

        XCTAssertEqual(flow.step, .done)
        XCTAssertTrue(flow.isLastStep)
    }

    func testRetreatStopsAtTheWelcomeStep() {
        var flow = OnboardingFlow(providers: [.claude])
        flow.retreat()

        XCTAssertEqual(flow.step, .welcome)
        XCTAssertTrue(flow.isFirstStep)
    }

    func testRetreatWalksBackThroughProviderSteps() {
        var flow = OnboardingFlow(step: .done, providers: [.claude, .codex])
        flow.retreat()

        XCTAssertEqual(flow.step, .providerSetup(.codex))

        flow.retreat()

        XCTAssertEqual(flow.step, .providerSetup(.claude))
    }

    func testDroppingTheCurrentProviderReturnsToTheScheduleStep() {
        var flow = OnboardingFlow(step: .providerSetup(.codex), providers: [.claude, .codex])
        flow.setProviders([.claude])

        XCTAssertEqual(flow.step, .schedule)
    }

    func testDroppingAnotherProviderKeepsTheCurrentStep() {
        var flow = OnboardingFlow(step: .providerSetup(.claude), providers: [.claude, .codex])
        flow.setProviders([.claude])

        XCTAssertEqual(flow.step, .providerSetup(.claude))
    }

    func testStepNumberingCountsFromOne() {
        var flow = OnboardingFlow(providers: [.claude])

        XCTAssertEqual(flow.stepNumber, 1)
        XCTAssertEqual(flow.stepCount, 4)

        flow.advance()

        XCTAssertEqual(flow.stepNumber, 2)
    }

    func testAScheduleWithoutProvidersStillReachesTheFinalStep() {
        var flow = OnboardingFlow(step: .providerSetup(.claude), providers: [])

        XCTAssertEqual(flow.steps, [.welcome, .schedule, .done])
        XCTAssertEqual(flow.step, .schedule)

        flow.advance()

        XCTAssertEqual(flow.step, .done)
    }
}
