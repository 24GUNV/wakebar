struct ClaudeRoutine: Decodable, Equatable, Sendable {
    let id: String
    let name: String
    let cronExpression: String?
    let enabled: Bool
    let prompt: String?

    init(
        id: String,
        name: String,
        cronExpression: String?,
        enabled: Bool,
        prompt: String?
    ) {
        self.id = id
        self.name = name
        self.cronExpression = cronExpression
        self.enabled = enabled
        self.prompt = prompt
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
            ?? values.decode(String.self, forKey: .triggerID)
        name = try values.decode(String.self, forKey: .name)
        cronExpression = try values.decodeIfPresent(String.self, forKey: .cronExpression)
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        let jobConfig = try values.decodeIfPresent(JobConfig.self, forKey: .jobConfig)
        prompt = jobConfig?.ccr.events?.first?.data.message.content
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case triggerID = "trigger_id"
        case name
        case cronExpression = "cron_expression"
        case enabled
        case jobConfig = "job_config"
    }

    private struct JobConfig: Decodable {
        let ccr: CCR
    }

    private struct CCR: Decodable {
        let events: [Event]?
    }

    private struct Event: Decodable {
        let data: EventData
    }

    private struct EventData: Decodable {
        let message: Message
    }

    private struct Message: Decodable {
        let content: String
    }
}
