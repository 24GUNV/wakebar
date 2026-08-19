import SwiftUI

@main
struct WakebarApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Wakebar", systemImage: "alarm") {
            MenuBarContentView(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            ScheduleSettingsView(model: model)
        }
    }
}
