import Foundation
import WakebarCore
import XCTest
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

@MainActor
final class CodexWakeModelTests: XCTestCase {
    private let week: TimeInterval = 7 * 24 * 60 * 60
    private let now = Date(timeIntervalSince1970: 1_789_000_000)

    func testSendsTheWakeAndConfirmsFromTheNextReading() async {
        let placeholder = weekly(resetsAt: now.addingTimeInterval(week), used: 0)
        let pinned = weekly(resetsAt: now.addingTimeInterval(week - 10 * 60), used: 0)
        let usage = StubProviderUsageReading(readings: [[placeholder], [pinned]])
        let requester = StubCodexStartRequester()
        let model = makeModel(usage: usage, requester: requester)

        let next = await model.tick(schedule: continuous)
        let prompts = await requester.prompts

        XCTAssertEqual(prompts, ["hi"])
        XCTAssertEqual(model.state, .confirmed(pinned, at: now))
        XCTAssertEqual(model.lastHandledAt, now)
        XCTAssertEqual(next, now.addingTimeInterval(CodexWakePlanner.settleInterval))
    }

    func testAnOpenWindowSendsNothing() async {
        let running = weekly(resetsAt: now.addingTimeInterval(3 * 24 * 60 * 60), used: 0.5)
        let usage = StubProviderUsageReading(readings: [[running]])
        let requester = StubCodexStartRequester()
        let model = makeModel(usage: usage, requester: requester)

        _ = await model.tick(schedule: continuous)
        let prompts = await requester.prompts

        XCTAssertEqual(prompts, [])
        XCTAssertEqual(model.state, .idle)
    }

    func testDisconnectedProviderDoesNotSend() async {
        let usage = StubProviderUsageReading(readings: [[weekly(resetsAt: now.addingTimeInterval(week), used: 0)]])
        let requester = StubCodexStartRequester(error: UsageWindowProviderIssue.missingCredentials)
        let model = makeModel(usage: usage, requester: requester, signedIn: false)

        _ = await model.tick(schedule: continuous)

        XCTAssertEqual(model.state, .failed("Connect Codex in Wakebar settings, then sign in with `codex login`.", at: now))
        XCTAssertNil(model.lastHandledAt)
        XCTAssertFalse(model.isSignedIn)
    }

    func testUsageOutageNeverSendsEvenAcrossRepeatedChecks() async {
        let usage = StubProviderUsageReading(readings: [], error: UsageWindowAPIError.network)
        let requester = StubCodexStartRequester()
        let model = makeModel(usage: usage, requester: requester)
        for _ in 0..<3 { _ = await model.tick(schedule: continuous) }
        let prompts = await requester.prompts
        XCTAssertTrue(prompts.isEmpty)
        XCTAssertNil(model.lastHandledAt)
    }

    func testEmptySuccessfulReadingDoesNotSend() async {
        let requester = StubCodexStartRequester()
        let model = makeModel(usage: StubProviderUsageReading(readings: [[]]), requester: requester)
        _ = await model.tick(schedule: continuous)
        let prompts = await requester.prompts
        XCTAssertTrue(prompts.isEmpty)
    }

    func testAmbiguousRequestIsRecordedBeforeRetry() async {
        let usage = StubProviderUsageReading(readings: [[weekly(resetsAt: now.addingTimeInterval(week), used: 0)]])
        let requester = StubCodexStartRequester(error: UsageWindowAPIError.network)
        let model = makeModel(usage: usage, requester: requester)
        _ = await model.tick(schedule: continuous)
        _ = await model.tick(schedule: continuous)
        let prompts = await requester.prompts
        XCTAssertEqual(prompts.count, 1)
        XCTAssertEqual(model.lastHandledAt, now)
    }

    private var continuous: WakeSchedule {
        var schedule = WakeSchedule.default
        schedule.isEnabled = true
        schedule.cadence = .continuous
        return schedule
    }

    private func makeModel(
        usage: StubProviderUsageReading,
        requester: StubCodexStartRequester,
        signedIn: Bool = true
    ) -> CodexWakeModel {
        let now = self.now
        let defaults = UserDefaults(suiteName: "CodexWakeModelTests.\(UUID().uuidString)")!
        defaults.removePersistentDomain(forName: "CodexWakeModelTests")
        return CodexWakeModel(
            usageReader: usage,
            requester: requester,
            credentialCheck: { signedIn },
            sleeper: ImmediateUsageWindowPollingSleeper(),
            defaults: defaults,
            now: { now },
            confirmationDelay: 0
        )
    }

    private func weekly(resetsAt: Date, used: Double) -> UsageWindow {
        UsageWindow(
            provider: .codex,
            duration: week,
            resetsAt: resetsAt,
            usedFraction: used,
            observedAt: now,
            confidence: .reported
        )
    }
}
