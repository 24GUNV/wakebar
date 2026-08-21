import SwiftUI
import WakebarCore

struct ProviderConfirmationButton: View {
    @Bindable var model: AppModel
    let provider: ProviderID

    var body: some View {
        Button("I've Finished Setup", action: confirmSchedule)
            .help("Wakebar records your confirmation. It cannot check the provider for you.")
    }

    private func confirmSchedule() {
        model.confirmProviderSchedule(provider)
    }
}
