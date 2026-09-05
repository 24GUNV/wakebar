import Foundation
import WakebarCore
import XCTest
#if SWIFT_PACKAGE
@testable import WakebarApp
#else
@testable import Wakebar
#endif

/// The reader's job is to be wrong in the least damaging direction: a provider
/// the API cannot speak for should fall back to the logs rather than vanish
/// from the popover, and one provider's failure must not blank the other.
///
/// Every case here is served from a stubbed URL protocol or a credential
/// directory that is empty on purpose. Nothing reaches the network and nothing
/// reads a real credential.
final class LiveUsageWindowReaderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_779_800_000)

    func testAProviderWhoseCallFailsFallsBackToTheLogs() async throws {
        let reader = makeReader(
            responses: [:],
            fallback: StubUsageWindowReader(windows: [sessionWindow(for: .claude)])
        )

        let windows = await reader.currentWindows(now: now)
        let issues = await reader.currentUsageWindowIssues()

        XCTAssertEqual(windows.map(\.provider), [.claude])
        XCTAssertEqual(issues[.claude], .network, "An estimated fallback must not hide a live-read failure from scheduling.")
        XCTAssertEqual(issues[.codex], .network, "Codex had nothing to recover, so it still owes an explanation.")
    }

    func testAProviderWithNoCredentialsSaysSoRatherThanGoingQuiet() async throws {
        let reader = makeReader(
            responses: [:],
            fallback: StubUsageWindowReader(windows: []),
            credentials: .absent
        )

        let windows = await reader.currentWindows(now: now)
        let issues = await reader.currentUsageWindowIssues()

        XCTAssertTrue(windows.isEmpty)
        XCTAssertEqual(issues[.claude], .missingCredentials)
        XCTAssertEqual(issues[.codex], .missingCredentials)
    }

    func testCodexKeepsOnlyTheWeeklyLimit() async throws {
        let reader = makeReader(
            responses: [
                .codex: """
                {"primary_window":{"used_percent":14.0,"reset_at":1787806845,"limit_window_seconds":604800},
                 "secondary_window":null}
                """,
            ],
            fallback: StubUsageWindowReader(windows: [sessionWindow(for: .codex)])
        )

        let windows = await reader.currentWindows(now: now)
        let issues = await reader.currentUsageWindowIssues()

        let codex = windows.filter { $0.provider == .codex }
        XCTAssertEqual(codex.filter(\.isSessionWindow).count, 0)
        XCTAssertEqual(codex.filter { !$0.isSessionWindow }.count, 1, "The reported weekly cap survives.")
        XCTAssertNil(issues[.codex])
    }

    func testOneProviderSucceedingDoesNotBlankTheOther() async throws {
        let reader = makeReader(
            responses: [
                .codex: """
                {"primary_window":{"used_percent":42.0,"reset_at":1787806845,"limit_window_seconds":604800},
                 "secondary_window":null}
                """,
            ],
            fallback: StubUsageWindowReader(windows: [sessionWindow(for: .claude)])
        )

        let windows = await reader.currentWindows(now: now)

        XCTAssertEqual(Set(windows.map(\.provider)), [.claude, .codex])
    }

    /// A rejected token and an under-scoped one send a user to two different
    /// places, so they must not arrive as the same sentence.
    func testClaudeSeparatesARejectedTokenFromAnUnderScopedOne() async throws {
        for (status, expected) in [
            (401, UsageWindowProviderIssue.unauthorized),
            (403, .insufficientScope),
            (429, .rateLimited),
        ] {
            let reader = makeReader(
                responses: [.claude: "{}"],
                statusCodes: [.claude: status],
                fallback: StubUsageWindowReader(windows: [])
            )

            _ = await reader.currentWindows(now: now)
            let issues = await reader.currentUsageWindowIssues()

            XCTAssertEqual(issues[.claude], expected, "HTTP \(status)")
        }
    }

    /// A weekly cap and no session window is Codex on a weekly-only plan. The
    /// weekly row already states that in the user's own terms, so restating it
    /// as a warning would invent a problem the provider does not have.
    func testAWeeklyOnlyProviderIsNotReportedAsAProblem() async throws {
        let reader = makeReader(
            responses: [
                .codex: """
                {"primary_window":{"used_percent":14.0,"reset_at":1787806845,"limit_window_seconds":604800},
                 "secondary_window":null}
                """,
            ],
            fallback: StubUsageWindowReader(windows: [])
        )

        _ = await reader.currentWindows(now: now)
        let issues = await reader.currentUsageWindowIssues()

        XCTAssertNil(issues[.codex])
    }

    /// The bug this guards is the one a user actually felt: denying the macOS
    /// credential prompt left nothing cached, so the very next popover open
    /// asked again. A refusal is a stable answer — it stays true until the user
    /// does something about it — and re-asking turns one refusal into a prompt
    /// on every click of the menu bar.
    func testARefusedCredentialIsNotAskedForAgainOnTheNextRead() async throws {
        let probe = CallCounter()
        let reader = makeReader(
            responses: [:],
            fallback: StubUsageWindowReader(windows: []),
            credentials: .absent,
            keychainProbe: probe
        )

        _ = await reader.currentWindows(now: now)
        _ = await reader.currentWindows(now: now.addingTimeInterval(30))
        let issues = await reader.currentUsageWindowIssues()

        XCTAssertEqual(probe.count, 1, "The second read is served from the cached refusal.")
        XCTAssertEqual(issues[.claude], .missingCredentials, "The refusal is still reported.")
    }

    /// A network error is the opposite case: it is usually over by the time
    /// anyone looks again, so believing it for a quarter of an hour would leave
    /// the popover blank long after the connection came back.
    func testATransientFailureIsRetriedSooner() async throws {
        let reader = makeReader(
            responses: [:],
            fallback: StubUsageWindowReader(windows: [])
        )

        _ = await reader.currentWindows(now: now)

        StubURLProtocol.responses["chatgpt.com"] = (
            200,
            Data("""
            {"primary_window":{"used_percent":14.0,"reset_at":1787806845,"limit_window_seconds":604800},
             "secondary_window":null}
            """.utf8)
        )
        let windows = await reader.currentWindows(now: now.addingTimeInterval(120))

        XCTAssertEqual(windows.filter { $0.provider == .codex }.count, 1, "Two minutes on, the reader tries again.")
    }

    // MARK: - Fixtures

    /// Whether the CLIs look installed. Placeholder credentials are what let a
    /// request reach the stubbed protocol at all; absent ones exercise the
    /// path where Wakebar has nothing to authenticate with.
    private enum Credentials {
        case placeholder
        case absent
    }

    private func makeReader(
        responses: [ProviderID: String],
        statusCodes: [ProviderID: Int] = [:],
        fallback: StubUsageWindowReader,
        credentials: Credentials = .placeholder,
        keychainProbe: CallCounter? = nil
    ) -> LiveUsageWindowReader {
        StubURLProtocol.responses = responses.reduce(into: [:]) { result, entry in
            result[Self.host(for: entry.key)] = (statusCodes[entry.key] ?? 200, Data(entry.value.utf8))
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)

        let home = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wakebar-\(UUID().uuidString)")
        if credentials == .placeholder {
            write(
                #"{"tokens":{"access_token":"placeholder","account_id":"placeholder"}}"#,
                to: home.appendingPathComponent(".codex/auth.json")
            )
            write(
                #"{"claudeAiOauth":{"accessToken":"placeholder"}}"#,
                to: home.appendingPathComponent(".claude/.credentials.json")
            )
        }

        let resolver = UsageWindowCredentialResolver(
            accessAllowed: { _ in true },
            environment: [
                "CODEX_HOME": home.appendingPathComponent(".codex").path,
                "CLAUDE_CONFIG_DIR": home.appendingPathComponent(".claude").path,
            ],
            homeDirectory: home,
            // Never the real Keychain: querying it prompts the user for their
            // live Claude Code token, which a test run has no business asking.
            keychainLookup: { _ in
                keychainProbe?.record()
                return .notFound
            }
        )

        return LiveUsageWindowReader(
            codexClient: CodexUsageAPIClient(credentialResolver: resolver, session: session),
            claudeClient: ClaudeUsageAPIClient(
                credentialStore: ClaudeCredentialStore(resolver: resolver),
                session: session
            ),
            fallback: fallback
        )
    }

    private func write(_ contents: String, to url: URL) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? Data(contents.utf8).write(to: url)
    }

    private func sessionWindow(for provider: ProviderID) -> UsageWindow {
        UsageWindow(
            provider: provider,
            duration: 5 * 60 * 60,
            resetsAt: now.addingTimeInterval(90 * 60),
            usedFraction: 0.5,
            observedAt: now,
            confidence: .inferred
        )
    }

    private static func host(for provider: ProviderID) -> String {
        switch provider {
        case .claude: "api.anthropic.com"
        case .codex: "chatgpt.com"
        }
    }
}

/// Counts how often the reader reaches for a credential, which is the only way
/// to see a prompt that a test must never actually raise.
private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0

    var count: Int {
        lock.withLock { calls }
    }

    func record() {
        lock.withLock { calls += 1 }
    }
}

private struct StubUsageWindowReader: UsageWindowReading {
    let windows: [UsageWindow]

    func currentWindows(now: Date) async -> [UsageWindow] { windows }
}

/// Answers only the hosts a test named. Anything else fails the request, which
/// is what keeps an unstubbed provider on its failure path.
private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [String: (status: Int, body: Data)] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let host = url.host,
              let stub = Self.responses[host]
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
