import Foundation
import WakebarCore

actor ClaudeUsageAPIClient: ProviderUsageReading {
    private let credentialStore: ClaudeCredentialStore
    private let credentialIntent: ClaudeCredentialIntent
    private let session: URLSession
    private let decoder = ClaudeUsageWindowDecoder()

    init(
        credentialStore: ClaudeCredentialStore = .shared,
        credentialIntent: ClaudeCredentialIntent = .background,
        session: URLSession? = nil
    ) {
        self.credentialStore = credentialStore
        self.credentialIntent = credentialIntent
        self.session = session ?? Self.makeSession()
    }

    func currentWindows(now: Date) async throws -> [UsageWindow] {
        let accessToken = try await credentialStore.credential(credentialIntent).accessToken
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else {
            throw UsageWindowAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("Wakebar", forHTTPHeaderField: "User-Agent")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UsageWindowAPIError.network
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageWindowAPIError.invalidResponse
        }
        // 401 and 403 are different diagnoses. Collapsing them tells a user
        // whose token merely expired to go looking for a missing scope.
        guard (200..<300).contains(httpResponse.statusCode) else {
            switch httpResponse.statusCode {
            case 401:
                await credentialStore.invalidate(tokenMatching: accessToken)
                throw UsageWindowAPIError.unauthorized
            case 403: throw UsageWindowAPIError.forbidden
            case 429: throw UsageWindowAPIError.rateLimited
            default: throw UsageWindowAPIError.network
            }
        }

        do {
            return try decoder.decode(data, observedAt: now)
        } catch {
            throw UsageWindowAPIError.invalidResponse
        }
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        return URLSession(configuration: configuration)
    }
}
