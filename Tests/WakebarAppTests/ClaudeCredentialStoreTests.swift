import Foundation
import XCTest
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

@MainActor
final class ClaudeCredentialStoreTests: XCTestCase {
    func testBackgroundCredentialUsesCachedCredentialWithinLifetime() async throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let keychain = StubClaudeKeychain(
            result: .data(credentialData(token: "cached", expiresAt: now.addingTimeInterval(3_600)))
        )
        let store = makeStore(keychain: keychain, clock: TestClock(now))

        _ = try await store.credential(.background)
        let credential = try await store.credential(.background)

        XCTAssertEqual(credential.accessToken, "cached")
        XCTAssertEqual(keychain.lookupCount, 1)
    }

    func testExpiredCachedCredentialIsRefetched() async throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let clock = TestClock(now)
        let keychain = StubClaudeKeychain(
            result: .data(credentialData(token: "expiring", expiresAt: now.addingTimeInterval(600)))
        )
        let store = makeStore(keychain: keychain, clock: clock)

        _ = try await store.credential(.background)
        clock.advance(by: 601)
        _ = try await store.credential(.background)

        XCTAssertEqual(keychain.lookupCount, 2)
    }

    func testCredentialWithoutExpiryUsesFallbackLifetime() async throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let clock = TestClock(now)
        let keychain = StubClaudeKeychain(
            result: .data(credentialData(token: "no-expiry"))
        )
        let store = makeStore(keychain: keychain, clock: clock)

        _ = try await store.credential(.background)
        clock.advance(by: 899)
        _ = try await store.credential(.background)
        XCTAssertEqual(keychain.lookupCount, 1)

        clock.advance(by: 2)
        _ = try await store.credential(.background)
        XCTAssertEqual(keychain.lookupCount, 2)
    }

    func testCredentialIntentControlsKeychainUIAllowance() async throws {
        let data = credentialData(token: "intent")
        let keychain = StubClaudeKeychain(result: .data(data))
        let clock = TestClock(Date(timeIntervalSince1970: 2_000_000_000))

        _ = try await makeStore(keychain: keychain, clock: clock).credential(.background)
        _ = try await makeStore(keychain: keychain, clock: clock).credential(.userInitiated)

        XCTAssertEqual(keychain.allowUIArguments, [false, true])
    }

    func testInteractionRequiredThrowsKeychainAuthorizationRequired() async {
        let keychain = StubClaudeKeychain(result: .interactionRequired)
        let store = makeStore(
            keychain: keychain,
            clock: TestClock(Date(timeIntervalSince1970: 2_000_000_000))
        )

        do {
            _ = try await store.credential(.background)
            XCTFail("Expected Keychain authorization to be required")
        } catch {
            XCTAssertEqual(error as? UsageWindowProviderIssue, .keychainAuthorizationRequired)
        }
    }

    func testInvalidatedTokenIsRejectedInBackgroundButUserCanRetry() async throws {
        let keychain = StubClaudeKeychain(
            result: .data(credentialData(token: "rejected"))
        )
        let store = makeStore(
            keychain: keychain,
            clock: TestClock(Date(timeIntervalSince1970: 2_000_000_000))
        )

        _ = try await store.credential(.background)
        await store.invalidate(tokenMatching: "rejected")

        do {
            _ = try await store.credential(.background)
            XCTFail("Expected the rejected token to remain unauthorized")
        } catch {
            XCTAssertEqual(error as? UsageWindowProviderIssue, .unauthorized)
        }

        let credential = try await store.credential(.userInitiated)
        XCTAssertEqual(credential.accessToken, "rejected")
        XCTAssertEqual(keychain.lookupCount, 3)
    }

    func testInvalidatingDifferentTokenKeepsCachedCredential() async throws {
        let keychain = StubClaudeKeychain(
            result: .data(credentialData(token: "cached"))
        )
        let store = makeStore(
            keychain: keychain,
            clock: TestClock(Date(timeIntervalSince1970: 2_000_000_000))
        )

        _ = try await store.credential(.background)
        await store.invalidate(tokenMatching: "different")
        let credential = try await store.credential(.background)

        XCTAssertEqual(credential.accessToken, "cached")
        XCTAssertEqual(keychain.lookupCount, 1)
    }

    func testDifferentTokenAfterInvalidationClearsRejection() async throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let clock = TestClock(now)
        let keychain = StubClaudeKeychain(
            result: .data(credentialData(token: "old", expiresAt: now.addingTimeInterval(3_600)))
        )
        let store = makeStore(keychain: keychain, clock: clock)

        _ = try await store.credential(.background)
        await store.invalidate(tokenMatching: "old")
        keychain.result = .data(
            credentialData(token: "new", expiresAt: now.addingTimeInterval(600))
        )

        let newCredential = try await store.credential(.background)
        XCTAssertEqual(newCredential.accessToken, "new")

        clock.advance(by: 601)
        keychain.result = .data(
            credentialData(token: "old", expiresAt: now.addingTimeInterval(3_600))
        )
        let oldCredential = try await store.credential(.background)

        XCTAssertEqual(oldCredential.accessToken, "old")
        XCTAssertEqual(keychain.lookupCount, 3)
    }

    func testConcurrentBackgroundCredentialsCoalesceKeychainRead() async throws {
        let keychain = StubClaudeKeychain(
            result: .data(credentialData(token: "coalesced")),
            lookupDelay: 0.05
        )
        let store = makeStore(
            keychain: keychain,
            clock: TestClock(Date(timeIntervalSince1970: 2_000_000_000))
        )

        let tokens = try await withThrowingTaskGroup(of: String.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    try await store.credential(.background).accessToken
                }
            }

            var tokens: [String] = []
            for try await token in group {
                tokens.append(token)
            }
            return tokens
        }

        XCTAssertEqual(tokens, Array(repeating: "coalesced", count: 8))
        XCTAssertEqual(keychain.lookupCount, 1)
    }

    private func makeStore(
        keychain: StubClaudeKeychain,
        clock: TestClock
    ) -> ClaudeCredentialStore {
        let resolver = UsageWindowCredentialResolver(
            accessAllowed: { _ in true },
            environment: [:],
            homeDirectory: URL(filePath: "/nonexistent-wakebar-test-home"),
            keychainLookup: { allowUI in keychain.lookup(allowUI: allowUI) }
        )
        return ClaudeCredentialStore(resolver: resolver, now: { clock.date })
    }
}

private final class StubClaudeKeychain: @unchecked Sendable {
    private let lock = NSLock()
    private var storedResult: UsageWindowCredentialResolver.KeychainResult
    private var storedAllowUIArguments: [Bool] = []
    private let lookupDelay: TimeInterval

    init(
        result: UsageWindowCredentialResolver.KeychainResult,
        lookupDelay: TimeInterval = 0
    ) {
        storedResult = result
        self.lookupDelay = lookupDelay
    }

    var result: UsageWindowCredentialResolver.KeychainResult {
        get { lock.withLock { storedResult } }
        set { lock.withLock { storedResult = newValue } }
    }

    var lookupCount: Int {
        lock.withLock { storedAllowUIArguments.count }
    }

    var allowUIArguments: [Bool] {
        lock.withLock { storedAllowUIArguments }
    }

    func lookup(allowUI: Bool) -> UsageWindowCredentialResolver.KeychainResult {
        lock.withLock { storedAllowUIArguments.append(allowUI) }
        if lookupDelay > 0 {
            Thread.sleep(forTimeInterval: lookupDelay)
        }
        return lock.withLock { storedResult }
    }
}

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var storedDate: Date

    init(_ date: Date) {
        storedDate = date
    }

    var date: Date {
        lock.withLock { storedDate }
    }

    func advance(by interval: TimeInterval) {
        lock.withLock { storedDate = storedDate.addingTimeInterval(interval) }
    }
}

private func credentialData(token: String, expiresAt: Date? = nil) -> Data {
    let expiry = expiresAt.map {
        ",\"expiresAt\":\($0.timeIntervalSince1970 * 1_000)"
    } ?? ""
    return Data(
        """
        {"claudeAiOauth":{"accessToken":"\(token)","refreshToken":"refresh"\(expiry)}}
        """.utf8
    )
}
