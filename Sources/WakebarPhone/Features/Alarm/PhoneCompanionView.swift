import SwiftUI

struct PhoneCompanionView: View {
    @Environment(\.scenePhase) private var scenePhase

    let model: PhoneCompanionModel

    var body: some View {
        NavigationStack {
            Group {
                if let payload = model.latestPayload {
                    List {
                        PhoneAlarmOverview(payload: payload)
                        PhoneAlarmStatusSection(status: model.status)
                        PhoneAlarmPermissionSection(model: model)
                        PhoneAlarmSyncSection(model: model, payload: payload)
                    }
                    .listSectionSpacing(.compact)
                } else {
                    ContentUnavailableView(
                        model.status.title,
                        systemImage: model.status.systemImage,
                        description: Text(model.status.detail)
                    )
                }
            }
            .navigationTitle("Wakebar")
            .tint(PhoneDesign.alarmTint)
            .task {
                await model.refresh()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await model.refresh()
                }
            }
        }
    }
}

#Preview("Synced schedule") {
    PhoneCompanionView(model: .preview)
}
