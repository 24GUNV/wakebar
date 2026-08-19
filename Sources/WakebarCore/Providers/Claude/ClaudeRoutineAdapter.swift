import Foundation

public struct ClaudeRoutineAdapter<CredentialStore, Transport>: ProviderAdapter
where CredentialStore: ClaudeRoutineCredentialStore, Transport: ClaudeRoutineTransport {
    public let id = ProviderID.claude

    private let configuration: ClaudeRoutineAPIConfiguration
    private let credentialStore: CredentialStore
    private let transport: Transport

    public init(
        configuration: ClaudeRoutineAPIConfiguration,
        credentialStore: CredentialStore,
        transport: Transport
    ) {
        self.configuration = configuration
        self.credentialStore = credentialStore
        self.transport = transport
    }

    public func probe() async -> ProviderSnapshot {
        do {
            guard let token = try await credentialStore.bearerToken(for: configuration.credential) else {
                return .notConnected(.claude)
            }
            guard Self.isPlausibleToken(token) else {
                return unavailableSnapshot(reason: ClaudeRoutineError.invalidCredential.userMessage)
            }

            // The fire-only API has no read-only probe. A plausible local token is not server verification.
            return ProviderSnapshot(
                provider: .claude,
                availability: .configuredUnverified("Token stored; API not verified"),
                fiveHourRemaining: nil,
                fiveHourReset: nil,
                weeklyRemaining: nil,
                weeklyReset: nil
            )
        } catch {
            return unavailableSnapshot(reason: "Wakebar could not read the Routine token from this Mac.")
        }
    }

    public func preview(_ request: TriggerRequest) async throws -> TriggerReceipt {
        try Self.validate(prompt: request.prompt)
        return TriggerReceipt(
            id: UUID(),
            provider: .claude,
            occurredAt: .now,
            outcome: .previewed
        )
    }

    public func trigger(_ request: TriggerRequest) async throws -> TriggerReceipt {
        let result = try await fire(request)
        return TriggerReceipt(
            id: UUID(),
            provider: .claude,
            occurredAt: .now,
            outcome: .sessionCreated,
            externalID: result.sessionID,
            externalURL: result.sessionURL
        )
    }

    public func fire(_ triggerRequest: TriggerRequest) async throws -> ClaudeRoutineFireResult {
        try Self.validate(prompt: triggerRequest.prompt)
        guard let token = try await credentialStore.bearerToken(for: configuration.credential) else {
            throw ClaudeRoutineError.missingCredential
        }
        guard Self.isPlausibleToken(token) else {
            throw ClaudeRoutineError.invalidCredential
        }

        var request = URLRequest(url: configuration.fireURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("experimental-cc-routine-2026-04-01", forHTTPHeaderField: "anthropic-beta")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ClaudeRoutineFireBody(text: triggerRequest.prompt))

        let response: ClaudeRoutineHTTPResponse
        do {
            response = try await transport.send(request)
        } catch let error as ClaudeRoutineError {
            throw error
        } catch {
            throw ClaudeRoutineError.serviceUnavailable
        }

        try Self.validate(response)
        let payload: ClaudeRoutineFireResponse
        do {
            payload = try JSONDecoder().decode(ClaudeRoutineFireResponse.self, from: response.data)
        } catch {
            throw ClaudeRoutineError.invalidResponse
        }

        guard payload.type == "routine_fire",
              payload.sessionID.hasPrefix("session_"),
              payload.sessionURL.scheme == "https",
              payload.sessionURL.host == "claude.ai"
        else {
            throw ClaudeRoutineError.invalidResponse
        }

        return ClaudeRoutineFireResult(sessionID: payload.sessionID, sessionURL: payload.sessionURL)
    }

    private static func validate(prompt: String) throws {
        guard prompt.count <= ClaudeRoutineProvisioner.maximumPromptLength else {
            throw ClaudeRoutineError.promptTooLong
        }
    }

    private static func isPlausibleToken(_ token: String) -> Bool {
        token.hasPrefix("sk-ant-oat01-") && token.count > "sk-ant-oat01-".count
    }

    private static func validate(_ response: ClaudeRoutineHTTPResponse) throws {
        switch response.statusCode {
        case 200:
            return
        case 400:
            throw ClaudeRoutineError.routinePausedOrInvalid
        case 401:
            throw ClaudeRoutineError.invalidCredential
        case 403:
            throw ClaudeRoutineError.accessDenied
        case 404:
            throw ClaudeRoutineError.routineNotFound
        case 429:
            throw ClaudeRoutineError.usageLimitReached(retryAfter: response.retryAfter)
        case 500, 503:
            throw ClaudeRoutineError.serviceUnavailable
        default:
            throw ClaudeRoutineError.requestFailed(statusCode: response.statusCode)
        }
    }

    private func unavailableSnapshot(reason: String) -> ProviderSnapshot {
        ProviderSnapshot(
            provider: .claude,
            availability: .unavailable(reason),
            fiveHourRemaining: nil,
            fiveHourReset: nil,
            weeklyRemaining: nil,
            weeklyReset: nil
        )
    }
}
