import Foundation
import WakebarCore

/// Sends Codex the one-word request that opens its usage window.
///
/// This is the same call Codex CLI makes for a turn, with no tools, no
/// project context and the lightest reasoning the model offers, so it costs
/// a few tokens. It goes to `chatgpt.com` with the credential the CLI wrote,
/// which is the only host that credential is ever sent to.
actor CodexPingClient: CodexStartRequesting {
    static let instructions = "Reply only with hi. Do not use tools."

    private let credentialResolver: UsageWindowCredentialResolver
    private let modelPreference: CodexModelPreference
    private let session: URLSession

    init(
        credentialResolver: UsageWindowCredentialResolver = UsageWindowCredentialResolver(),
        modelPreference: CodexModelPreference = CodexModelPreference(),
        session: URLSession? = nil
    ) {
        self.credentialResolver = credentialResolver
        self.modelPreference = modelPreference
        self.session = session ?? Self.makeSession()
    }

    func requestStart(prompt: String) async throws -> CodexStartRequestOutcome {
        let credential = try credentialResolver.codexCredential()
        guard let url = URL(string: "https://chatgpt.com/backend-api/codex/responses") else {
            throw UsageWindowAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credential.accountID, forHTTPHeaderField: "chatgpt-account-id")
        request.setValue("responses=experimental", forHTTPHeaderField: "OpenAI-Beta")
        request.setValue("codex_cli_rs", forHTTPHeaderField: "originator")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Wakebar", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(
            Body(model: modelPreference.model, instructions: Self.instructions, prompt: prompt)
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UsageWindowAPIError.network
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageWindowAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            switch httpResponse.statusCode {
            case 401: throw UsageWindowAPIError.unauthorized
            case 403: throw UsageWindowAPIError.forbidden
            case 429: throw UsageWindowAPIError.rateLimited
            default: throw UsageWindowAPIError.network
            }
        }

        // The stream ends with a completed event when Codex answered. A 200
        // that never gets there was cut off, and it is not known whether the
        // turn was counted.
        let body = String(decoding: data, as: UTF8.self)
        guard body.contains("\"type\":\"response.completed\"") else {
            throw UsageWindowAPIError.invalidResponse
        }
        return .sent
    }

    private struct Body: Encodable {
        struct Message: Encodable {
            struct Content: Encodable {
                let type = "input_text"
                let text: String
            }

            let type = "message"
            let role = "user"
            let content: [Content]
        }

        struct Reasoning: Encodable {
            let effort = "low"
        }

        let model: String
        let instructions: String
        let input: [Message]
        let tools: [String] = []
        let toolChoice = "auto"
        let parallelToolCalls = false
        let reasoning = Reasoning()
        let store = false
        let stream = true
        let include: [String] = []

        init(model: String, instructions: String, prompt: String) {
            self.model = model
            self.instructions = instructions
            self.input = [Message(content: [.init(text: prompt)])]
        }

        enum CodingKeys: String, CodingKey {
            case model, instructions, input, tools, reasoning, store, stream, include
            case toolChoice = "tool_choice"
            case parallelToolCalls = "parallel_tool_calls"
        }
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 90
        return URLSession(configuration: configuration)
    }
}
