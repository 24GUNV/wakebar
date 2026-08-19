import SwiftUI

struct PausedScheduleView: View {
    var body: some View {
        ContentUnavailableView(
            "Schedule paused",
            systemImage: "pause.circle",
            description: Text("Turn the schedule on when you want Wakebar to prepare the next wake plan.")
        )
        .padding(.vertical, WakebarDesign.sectionSpacing)
    }
}
