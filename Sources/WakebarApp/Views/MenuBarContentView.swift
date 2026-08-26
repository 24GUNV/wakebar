import SwiftUI
import WakebarCore

struct MenuBarContentView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        WakeSummaryView(model: model)
        .frame(
            minWidth: WakebarDesign.minimumPopoverWidth,
            idealWidth: WakebarDesign.popoverWidth,
            maxWidth: WakebarDesign.maximumPopoverWidth
        )
        .environment(\.timeZone, model.schedule.timeZone)
        .task {
            await model.load()
            // Backstop for the status-item trigger: a first run must reach the
            // setup guide even if the label's task never ran.
            if model.shouldPresentOnboarding {
                model.beginOnboarding()
                NSApplication.shared.activate()
                openWindow(id: "onboarding")
            }
            while !Task.isCancelled {
                // This task exists only for the lifetime of the open popover.
                // The reader's cache controls provider calls within that time.
                await model.refreshUsageWindows()
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    return
                }
            }
        }
    }
}
