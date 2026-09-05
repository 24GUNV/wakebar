import Foundation
import WakebarCore

actor ClaudeRoutinesClient: ClaudeRoutinesServing {
    static let beta = "ccr-triggers-2026-01-30"
    private static var defaultBaseURL: URL {
        guard let url = URL(string: "https://api.anthropic.com") else {
            preconditionFailure("The Anthropic API URL is invalid.")
        }
        return url
    }

    private let baseURL: URL
    private let credentialStore: ClaudeCredentialStore
    private let transport: any ClaudeRoutinesTransport
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var cachedOrganization: (accessToken: String, id: String)?

    init(
        baseURL: URL? = nil,
        credentialStore: ClaudeCredentialStore = .shared,
        transport: any ClaudeRoutinesTransport = URLSessionClaudeRoutinesTransport()
    ) {
        self.baseURL = baseURL ?? Self.defaultBaseURL
        self.credentialStore = credentialStore
        self.transport = transport
    }

    func listRoutines(credentialIntent: ClaudeCredentialIntent) async throws -> [ClaudeRoutine] {
        let response = try await send(
            path: "/v1/code/triggers",
            method: "GET",
            usesBeta: true,
            credentialIntent: credentialIntent
        )
        do {
            return try decoder.decode(RoutineListResponse.self, from: response.data).data
        } catch {
            throw ClaudeRoutinesError.invalidResponse
        }
    }

    func routine(
        id: String,
        credentialIntent: ClaudeCredentialIntent
    ) async throws -> ClaudeRoutine {
        let response = try await send(
            path: "/v1/code/triggers/\(id)",
            method: "GET",
            usesBeta: true,
            credentialIntent: credentialIntent
        )
        return try decodeRoutine(response.data)
    }

    func createRoutine(
        _ spec: RoutineSpec,
        environmentID: String,
        credentialIntent: ClaudeCredentialIntent
    ) async throws {
        let payload = RoutinePayload(spec: spec, environmentID: environmentID)
        _ = try await send(
            path: "/v1/code/triggers",
            method: "POST",
            usesBeta: true,
            credentialIntent: credentialIntent,
            body: try encoder.encode(payload)
        )
    }

    func updateRoutine(
        id: String,
        spec: RoutineSpec,
        environmentID: String,
        credentialIntent: ClaudeCredentialIntent
    ) async throws {
        let payload = RoutinePayload(spec: spec, environmentID: environmentID)
        _ = try await send(
            path: "/v1/code/triggers/\(id)",
            method: "POST",
            usesBeta: true,
            credentialIntent: credentialIntent,
            body: try encoder.encode(payload)
        )
    }

    func deleteRoutine(
        id: String,
        credentialIntent: ClaudeCredentialIntent
    ) async throws {
        _ = try await send(
            path: "/v1/code/triggers/\(id)",
            method: "DELETE",
            usesBeta: true,
            credentialIntent: credentialIntent
        )
    }

    func runRoutine(
        id: String,
        credentialIntent: ClaudeCredentialIntent
    ) async throws {
        _ = try await send(
            path: "/v1/code/triggers/\(id)/run",
            method: "POST",
            usesBeta: true,
            credentialIntent: credentialIntent,
            body: Data("{}".utf8)
        )
    }

    func environments(
        credentialIntent: ClaudeCredentialIntent
    ) async throws -> [ClaudeEnvironment] {
        let response = try await send(
            path: "/v1/environment_providers",
            method: "GET",
            usesBeta: false,
            credentialIntent: credentialIntent
        )
        do {
            return try decoder.decode(EnvironmentListResponse.self, from: response.data).environments
        } catch {
            throw ClaudeRoutinesError.invalidResponse
        }
    }

    private func decodeRoutine(_ data: Data) throws -> ClaudeRoutine {
        do {
            if let wrapped = try? decoder.decode(RoutineResponse.self, from: data) {
                return wrapped.trigger
            }
            return try decoder.decode(ClaudeRoutine.self, from: data)
        } catch {
            throw ClaudeRoutinesError.invalidResponse
        }
    }

    private func send(
        path: String,
        method: String,
        usesBeta: Bool,
        credentialIntent: ClaudeCredentialIntent,
        body: Data? = nil
    ) async throws -> ClaudeRoutinesHTTPResponse {
        let accessToken = try await resolveAccessToken(credentialIntent: credentialIntent)
        do {
            return try await send(
                path: path,
                method: method,
                usesBeta: usesBeta,
                body: body,
                accessToken: accessToken
            )
        } catch ClaudeRoutinesError.noAuthentication {
            // The Keychain may hold a newer token than the one the server
            // just refused; one retry with it is legitimate. If the re-read
            // returns the same token the store refuses it, ending the loop.
            await credentialStore.invalidate(tokenMatching: accessToken)
            let freshToken = try await resolveAccessToken(credentialIntent: credentialIntent)
            guard freshToken != accessToken else {
                throw ClaudeRoutinesError.noAuthentication
            }
            return try await send(
                path: path,
                method: method,
                usesBeta: usesBeta,
                body: body,
                accessToken: freshToken
            )
        }
    }

    private func resolveAccessToken(
        credentialIntent: ClaudeCredentialIntent
    ) async throws -> String {
        do {
            return try await credentialStore.credential(credentialIntent).accessToken
        } catch {
            throw ClaudeRoutinesError.noAuthentication
        }
    }

    private func send(
        path: String,
        method: String,
        usesBeta: Bool,
        body: Data?,
        accessToken: String
    ) async throws -> ClaudeRoutinesHTTPResponse {
        let organizationID = try await organizationID(accessToken: accessToken)
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw ClaudeRoutinesError.apiChanged
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(organizationID, forHTTPHeaderField: "x-organization-uuid")
        request.setValue("Wakebar", forHTTPHeaderField: "User-Agent")
        if usesBeta {
            request.setValue(Self.beta, forHTTPHeaderField: "anthropic-beta")
        }

        return try await perform(request)
    }

    private func organizationID(accessToken: String) async throws -> String {
        if let cachedOrganization, cachedOrganization.accessToken == accessToken {
            return cachedOrganization.id
        }
        guard let url = URL(string: "/api/oauth/profile", relativeTo: baseURL) else {
            throw ClaudeRoutinesError.apiChanged
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("Wakebar", forHTTPHeaderField: "User-Agent")

        let response = try await perform(request)
        let profile: OAuthProfileResponse
        do {
            profile = try decoder.decode(OAuthProfileResponse.self, from: response.data)
        } catch {
            throw ClaudeRoutinesError.invalidResponse
        }
        guard !profile.organization.uuid.isEmpty else {
            throw ClaudeRoutinesError.invalidResponse
        }
        cachedOrganization = (accessToken, profile.organization.uuid)
        return profile.organization.uuid
    }

    private func perform(_ request: URLRequest) async throws -> ClaudeRoutinesHTTPResponse {
        let response: ClaudeRoutinesHTTPResponse
        do {
            response = try await transport.send(request)
        } catch let error as ClaudeRoutinesError {
            throw error
        } catch {
            throw ClaudeRoutinesError.network
        }

        guard (200..<300).contains(response.statusCode) else {
            switch response.statusCode {
            case 400 where betaWasRejected(in: response.data):
                throw ClaudeRoutinesError.apiChanged
            case 401:
                throw ClaudeRoutinesError.noAuthentication
            case 403:
                throw ClaudeRoutinesError.accessDenied
            case 404:
                throw ClaudeRoutinesError.apiChanged
            case 429:
                throw ClaudeRoutinesError.rateLimited
            default:
                throw ClaudeRoutinesError.requestFailed(statusCode: response.statusCode)
            }
        }
        return response
    }

    private func betaWasRejected(in data: Data) -> Bool {
        guard let message = String(data: data, encoding: .utf8)?.lowercased() else {
            return false
        }
        return message.contains("beta") || message.contains("ccr-triggers")
    }

    private struct RoutineListResponse: Decodable {
        let data: [ClaudeRoutine]
    }

    private struct RoutineResponse: Decodable {
        let trigger: ClaudeRoutine
    }

    private struct EnvironmentListResponse: Decodable {
        let environments: [ClaudeEnvironment]
    }

    private struct OAuthProfileResponse: Decodable {
        let organization: Organization

        struct Organization: Decodable {
            let uuid: String
        }
    }

    private struct RoutinePayload: Encodable {
        let name: String
        let cronExpression: String
        let enabled: Bool
        let jobConfig: JobConfig

        init(spec: RoutineSpec, environmentID: String) {
            name = spec.name
            cronExpression = spec.cronExpression
            enabled = spec.enabled
            jobConfig = JobConfig(
                ccr: CCR(
                    environmentID: environmentID,
                    sessionContext: SessionContext(
                        model: "claude-sonnet-5",
                        allowedTools: []
                    ),
                    events: [
                        Event(
                            data: EventData(
                                uuid: UUID().uuidString.lowercased(),
                                sessionID: "",
                                type: "user",
                                message: Message(role: "user", content: spec.prompt)
                            )
                        ),
                    ]
                )
            )
        }

        enum CodingKeys: String, CodingKey {
            case name
            case cronExpression = "cron_expression"
            case enabled
            case jobConfig = "job_config"
        }
    }

    private struct JobConfig: Encodable {
        let ccr: CCR
    }

    private struct CCR: Encodable {
        let environmentID: String
        let sessionContext: SessionContext
        let events: [Event]

        enum CodingKeys: String, CodingKey {
            case environmentID = "environment_id"
            case sessionContext = "session_context"
            case events
        }
    }

    private struct SessionContext: Encodable {
        let model: String
        let allowedTools: [String]

        enum CodingKeys: String, CodingKey {
            case model
            case allowedTools = "allowed_tools"
        }
    }

    private struct Event: Encodable {
        let data: EventData
    }

    private struct EventData: Encodable {
        let uuid: String
        let sessionID: String
        let type: String
        let message: Message

        enum CodingKeys: String, CodingKey {
            case uuid
            case sessionID = "session_id"
            case type
            case parentToolUseID = "parent_tool_use_id"
            case message
        }

        func encode(to encoder: any Encoder) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode(uuid, forKey: .uuid)
            try values.encode(sessionID, forKey: .sessionID)
            try values.encode(type, forKey: .type)
            try values.encodeNil(forKey: .parentToolUseID)
            try values.encode(message, forKey: .message)
        }
    }

    private struct Message: Encodable {
        let role: String
        let content: String
    }
}
