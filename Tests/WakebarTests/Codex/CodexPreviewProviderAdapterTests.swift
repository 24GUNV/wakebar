import Foundation
import XCTest
@testable import WakebarCore

final class CodexPreviewProviderAdapterTests: XCTestCase {
    func testPreviewNeverClaimsPromptWasSentOrWindowWasConfirmed() async throws {
        let adapter = CodexPreviewProviderAdapter()
        let request = TriggerRequest(
            scheduleID: UUID(),
            plannedFireDate: .now,
            prompt: "hi"
        )

        let receipt = try await adapter.preview(request)

        XCTAssertEqual(receipt.provider, .codex)
        XCTAssertEqual(receipt.outcome, .previewed)
    }

    func testLiveTriggerRemainsDisabled() async {
        let adapter = CodexPreviewProviderAdapter()
        let request = TriggerRequest(
            scheduleID: UUID(),
            plannedFireDate: .now,
            prompt: "hi"
        )

        do {
            try await adapter.trigger(request)
            XCTFail("Expected live execution to remain disabled")
        } catch {
            XCTAssertTrue(error is ProviderAdapterError)
        }
    }
}
