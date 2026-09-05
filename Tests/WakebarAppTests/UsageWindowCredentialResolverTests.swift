import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

final class UsageWindowCredentialResolverTests: XCTestCase {
    func testClaudeCredentialIncludesExpiryAndRefreshTokenMetadata() throws {
        let expiryMilliseconds = 1_800_000_000_000.0
        let data = Data(
            """
            {"claudeAiOauth":{
              "accessToken":"oauth-test",
              "refreshToken":"refresh-test",
              "expiresAt":\(expiryMilliseconds)
            }}
            """.utf8
        )
        let resolver = UsageWindowCredentialResolver(
            environment: [:],
            homeDirectory: URL(filePath: "/nonexistent-wakebar-test-home"),
            keychainLookup: { _ in .data(data) }
        )

        let credential = try resolver.claudeCredential()

        XCTAssertEqual(credential.accessToken, "oauth-test")
        XCTAssertEqual(credential.expiresAt, Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertTrue(credential.hasRefreshToken)
    }

    func testClaudeCredentialReadsPlainJSONFromSecurityCLI() throws {
        let framework = StubKeychainLookup(result: .unavailable)
        let resolver = makeResolver(
            framework: framework,
            cliResult: .completed(stdout: credentialData(token: "plain-cli") + Data("\n".utf8), exitCode: 0)
        )

        let credential = try resolver.claudeCredential()

        XCTAssertEqual(credential.accessToken, "plain-cli")
        XCTAssertEqual(framework.lookupCount, 0)
    }

    func testClaudeCredentialDecodesHexJSONFromSecurityCLI() throws {
        let framework = StubKeychainLookup(result: .unavailable)
        let json = credentialData(token: "hex-cli")
        let hex = hexEncoded(json)
        let resolver = makeResolver(
            framework: framework,
            cliResult: .completed(stdout: Data("\(hex)\n".utf8), exitCode: 0)
        )

        let credential = try resolver.claudeCredential()

        XCTAssertEqual(credential.accessToken, "hex-cli")
        XCTAssertEqual(framework.lookupCount, 0)
    }

    func testSecurityCLIExit44ReturnsNotFoundWithoutFrameworkFallback() {
        let framework = StubKeychainLookup(result: .data(credentialData(token: "framework")))
        let resolver = makeResolver(
            framework: framework,
            cliResult: .completed(stdout: Data(), exitCode: 44)
        )

        XCTAssertThrowsError(try resolver.claudeCredential()) { error in
            XCTAssertEqual(error as? UsageWindowProviderIssue, .missingCredentials)
        }
        XCTAssertEqual(framework.lookupCount, 0)
    }

    func testBackgroundReadUsesSecurityCLIWithoutTouchingTheFramework() throws {
        let framework = StubKeychainLookup(result: .data(credentialData(token: "framework")))
        let resolver = makeResolver(
            framework: framework,
            cliResult: .completed(stdout: credentialData(token: "cli"), exitCode: 0)
        )

        let credential = try resolver.claudeCredential(allowUI: false)

        XCTAssertEqual(credential.accessToken, "cli")
        XCTAssertEqual(framework.lookupCount, 0)
    }

    func testBackgroundReadFallsBackToQuietFrameworkLookupWhenSecurityCLIFails() throws {
        let framework = StubKeychainLookup(result: .data(credentialData(token: "framework")))
        let resolver = makeResolver(framework: framework, cliResult: .launchFailed)

        let credential = try resolver.claudeCredential(allowUI: false)

        XCTAssertEqual(credential.accessToken, "framework")
        XCTAssertEqual(framework.allowUIArguments, [false])
    }

    func testUnparseableSecurityCLIOutputFallsBackToFrameworkLookup() throws {
        let framework = StubKeychainLookup(result: .data(credentialData(token: "framework")))
        let resolver = makeResolver(
            framework: framework,
            cliResult: .completed(stdout: Data("not-json\n".utf8), exitCode: 0)
        )

        let credential = try resolver.claudeCredential()

        XCTAssertEqual(credential.accessToken, "framework")
        XCTAssertEqual(framework.lookupCount, 1)
    }

    func testSecurityCLITimeoutFallsBackToFrameworkLookup() throws {
        let framework = StubKeychainLookup(result: .data(credentialData(token: "framework")))
        let resolver = makeResolver(framework: framework, cliResult: .timedOut)

        let credential = try resolver.claudeCredential()

        XCTAssertEqual(credential.accessToken, "framework")
        XCTAssertEqual(framework.allowUIArguments, [true])
    }

    private func makeResolver(
        framework: StubKeychainLookup,
        cliResult: UsageWindowCredentialResolver.SecurityCLIRunResult
    ) -> UsageWindowCredentialResolver {
        UsageWindowCredentialResolver(
            environment: [:],
            homeDirectory: URL(filePath: "/nonexistent-wakebar-test-home"),
            keychainLookup: { allowUI in framework.lookup(allowUI: allowUI) },
            securityCLIRunner: { cliResult }
        )
    }
}

private func credentialData(token: String) -> Data {
    Data("""
    {"claudeAiOauth":{"accessToken":"\(token)","refreshToken":"refresh"}}
    """.utf8)
}

private func hexEncoded(_ data: Data) -> String {
    let digits = Array("0123456789abcdef".utf8)
    return String(
        decoding: data.flatMap { byte in
            [digits[Int(byte >> 4)], digits[Int(byte & 0x0F)]]
        },
        as: UTF8.self
    )
}
