import SwiftUI
import WakebarCore

struct MenuBarContentView: View {
    @Bindable var model: AppModel
    @State private var showsEditor = false

    var body: some View {
        Group {
            if showsEditor {
                ScheduleEditorView(
                    schedule: model.schedule,
                    onCancel: closeEditor,
                    onSave: saveSchedule
                )
            } else {
                WakeSummaryView(model: model, onEdit: openEditor)
            }
        }
        .frame(
            minWidth: WakebarDesign.popoverWidth,
            idealWidth: WakebarDesign.popoverWidth,
            maxWidth: WakebarDesign.popoverWidth
        )
        .task {
            await model.load()
        }
    }

    private func openEditor() {
        showsEditor = true
    }

    private func closeEditor() {
        showsEditor = false
    }

    private func saveSchedule(_ schedule: WakeSchedule) {
        model.saveSchedule(schedule)
        showsEditor = false
    }
}
