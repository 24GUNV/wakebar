import Foundation
import WakebarCore
import XCTest
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

final class ClaudeRoutineStartRequesterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_787_500_000)

    func testCreatesMissingManagedMorningBeforeRun() async throws {
        var schedule = WakeSchedule.default
        schedule.isEnabled = true
        let service = StubClaudeRoutinesService()
        let now = self.now
        let requester = ClaudeRoutineStartRequester(client: service, now: { now })

        try await requester.requestStart(for: schedule)
        let createdNames = await service.createdSpecs.map(\.name)
        let runIDs = await service.runIDs
        let credentialIntents = await service.credentialIntents

        XCTAssertEqual(createdNames, [
            "\(RoutinePlanCompiler.namePrefix(for: schedule)) Morning",
        ])
        XCTAssertEqual(runIDs, ["created-1"])
        XCTAssertFalse(credentialIntents.isEmpty)
        XCTAssertTrue(credentialIntents.allSatisfy { $0 == .userInitiated })
    }

    func testRunsExistingMorningWithoutCreatingRoutine() async throws {
        var schedule = WakeSchedule.default
        schedule.isEnabled = true
        let name = "\(RoutinePlanCompiler.namePrefix(for: schedule)) Morning"
        let service = StubClaudeRoutinesService(
            routines: [
                ClaudeRoutine(
                    id: "morning",
                    name: name,
                    cronExpression: "0 0 * * 1",
                    enabled: true,
                    prompt: "yes"
                ),
            ]
        )
        let now = self.now
        let requester = ClaudeRoutineStartRequester(client: service, now: { now })

        try await requester.requestStart(for: schedule)
        let createdSpecs = await service.createdSpecs
        let runIDs = await service.runIDs
        let credentialIntents = await service.credentialIntents

        XCTAssertTrue(createdSpecs.isEmpty)
        XCTAssertEqual(runIDs, ["morning"])
        XCTAssertTrue(credentialIntents.allSatisfy { $0 == .userInitiated })
    }
}
