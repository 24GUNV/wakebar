import Foundation

public struct CodexCLIPreviewPlan: Equatable, Sendable {
    public let executable: String
    public let arguments: [String]
    public let prompt: String
    public let prerequisites: [String]
    public let resultMeaning: String

    public init(prompt: String = "hi") throws {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            throw CodexCLIPreviewError.emptyPrompt
        }

        executable = "codex"
        arguments = [
            "exec",
            "--ephemeral",
            "--json",
            "--sandbox",
            "read-only",
            trimmedPrompt,
        ]
        self.prompt = trimmedPrompt
        prerequisites = [
            "Codex CLI is installed and authenticated.",
            "The external scheduler runs inside a trusted Git repository.",
            "The selected host is awake when the job fires.",
        ]
        resultMeaning = CodexUsageWindowEffect.unverified.detail
    }
}
