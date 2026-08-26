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
}
