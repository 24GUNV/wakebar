import SwiftUI
import WakebarCore

struct MenuBarContentView: View {
    @Bindable var model: AppModel

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
        }
    }
}
