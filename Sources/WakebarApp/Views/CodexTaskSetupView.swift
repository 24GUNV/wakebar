import AppKit
import SwiftUI
import WakebarCore

struct CodexTaskSetupView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: WakebarDesign.sectionSpacing) {
            Text("You create each task in ChatGPT. Creating a scheduled task does not send a prompt. Each task fire replies only with hi and leaves the task enabled.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(taskSpecs, id: \.name) { spec in
                VStack(alignment: .leading, spacing: WakebarDesign.compactSpacing) {
                    LabeledContent("Task name", value: spec.name)
                    LabeledContent("Schedule", value: model.codexSetup.scheduleDescription(for: spec))
                    LabeledContent("Prompt", value: spec.prompt)
                }
            }

            HStack(spacing: WakebarDesign.compactSpacing) {
                Button("Copy instructions", action: copyInstructions)
                    .buttonStyle(.borderedProminent)

                if let scheduledTasksURL = Self.scheduledTasksURL {
                    Link("Open chatgpt.com/scheduled", destination: scheduledTasksURL)
                }
            }

            Toggle(confirmationTitle, isOn: $model.isCodexTaskConfirmed)

            if let confirmedAt = model.codexTaskConfirmedAt {
                Text("Recorded \(confirmedAt.formatted(date: .abbreviated, time: .shortened)). This confirms only that you created the task.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

        }
    }

    private var taskSpecs: [CodexTaskSpec] {
        model.codexSetup.taskSpecs(for: model.schedule)
    }

    private var confirmationTitle: String {
        taskSpecs.count == 1 ? "I created the task" : "I created the tasks"
    }

    private func copyInstructions() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(
            model.codexSetup.instructions(for: model.schedule),
            forType: .string
        )
    }

    private static let scheduledTasksURL = URL(string: "https://chatgpt.com/scheduled")
}
