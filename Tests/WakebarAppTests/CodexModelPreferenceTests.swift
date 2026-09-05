import XCTest
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

final class CodexModelPreferenceTests: XCTestCase {
    func testReadsTheTopLevelModel() {
        let toml = """
        model = "gpt-5.6-sol"
        model_reasoning_effort = "low"

        [profiles.fast]
        model = "gpt-5.4-mini"
        """

        XCTAssertEqual(CodexModelPreference.topLevelModel(in: toml), "gpt-5.6-sol")
    }

    func testIgnoresModelsInsideTables() {
        let toml = """
        approval_policy = "never"

        [profiles.fast]
        model = "gpt-5.4-mini"
        """

        XCTAssertNil(CodexModelPreference.topLevelModel(in: toml))
    }

    func testDoesNotMistakeAPrefixedKeyForTheModel() {
        XCTAssertNil(CodexModelPreference.topLevelModel(in: "model_provider = \"openai\""))
        XCTAssertEqual(
            CodexModelPreference.topLevelModel(in: "model = 'gpt-5.5' # comment"),
            "gpt-5.5"
        )
    }

    func testFallsBackWhenTheFileIsMissing() {
        let preference = CodexModelPreference(
            environment: [:],
            homeDirectory: URL(filePath: "/nonexistent-wakebar-test-home")
        )

        XCTAssertEqual(preference.model, CodexModelPreference.fallbackModel)
    }
}
