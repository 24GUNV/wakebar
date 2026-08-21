import SwiftUI

@main
struct WakebarApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(model: model)
        } label: {
            MenuBarIconView(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("Wakebar", id: "settings") {
            ScheduleSettingsView(model: model)
        }
        .defaultSize(width: WakebarDesign.windowMinimumWidth, height: 520)
    }
}

/// The menu bar icon carries one bit: is a wake scheduled or not. Loading here
/// rather than in the popover means the icon is already right at launch.
private struct MenuBarIconView: View {
    let model: AppModel

    var body: some View {
        Image(systemName: model.isScheduleActive ? "alarm.fill" : "alarm")
            .accessibilityLabel(model.isScheduleActive ? "Wakebar, wake scheduled" : "Wakebar, off")
            .task {
                await model.load()
            }
    }
}
