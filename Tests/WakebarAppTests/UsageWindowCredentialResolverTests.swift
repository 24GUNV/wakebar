import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

final class UsageWindowCredentialResolverTests: XCTestCase {
    func testNoConsentPreventsBothCredentialReads() {
        let lookup = StubKeychainLookup(result: .unavailable)
        let resolver = UsageWindowCredentialResolver(
            accessAllowed: { _ in false },
            environment: [:],
            homeDirectory: URL(filePath: "/nonexistent-wakebar-test-home"),
            keychainLookup: { lookup.lookup(allowUI: $0) }
        )
        XCTAssertThrowsError(try resolver.claudeCredential()) {
            XCTAssertEqual($0 as? UsageWindowProviderIssue, .connectionRequired)
        }
        XCTAssertThrowsError(try resolver.codexCredential()) {
            XCTAssertEqual($0 as? UsageWindowProviderIssue, .connectionRequired)
        }
        XCTAssertEqual(lookup.lookupCount, 0)
    }

    func testConsentForOneProviderDoesNotAuthorizeTheOther() {
        let resolver = UsageWindowCredentialResolver(accessAllowed: { $0 == .claude })
        XCTAssertThrowsError(try resolver.codexCredential()) {
            XCTAssertEqual($0 as? UsageWindowProviderIssue, .connectionRequired)
        }
    }

    func testBackgroundReadUsesQuietAppIdentityAndPreservesMetadata() throws {
        let data = Data(#"{"claudeAiOauth":{"accessToken":"fixture","expiresAt":1800000000000,"refreshToken":"fixture-refresh"}}"#.utf8)
        let lookup = StubKeychainLookup(result: .data(data))
        let resolver = UsageWindowCredentialResolver(
            accessAllowed: { _ in true },
            environment: [:],
            homeDirectory: URL(filePath: "/nonexistent-wakebar-test-home"),
            keychainLookup: { lookup.lookup(allowUI: $0) }
        )
        let credential = try resolver.claudeCredential(allowUI: false)
        XCTAssertEqual(credential.accessToken, "fixture")
        XCTAssertEqual(credential.expiresAt, Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertTrue(credential.hasRefreshToken)
        XCTAssertEqual(lookup.allowUIArguments, [false])
    }

    func testDeniedKeychainReadDoesNotFallBackToAnotherIdentity() {
        let lookup = StubKeychainLookup(result: .interactionRequired)
        let resolver = UsageWindowCredentialResolver(
            accessAllowed: { _ in true },
            environment: [:],
            homeDirectory: URL(filePath: "/nonexistent-wakebar-test-home"),
            keychainLookup: { lookup.lookup(allowUI: $0) }
        )
        XCTAssertThrowsError(try resolver.claudeCredential()) {
            XCTAssertEqual($0 as? UsageWindowProviderIssue, .keychainAuthorizationRequired)
        }
        XCTAssertEqual(lookup.allowUIArguments, [true])
    }
}
