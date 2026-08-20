import SwiftUI
import WakebarCore

struct ProviderConfirmationButton: View {
    @Bindable var model: AppModel
    let provider: ProviderID

    var body: some View {
        Button("I've finished setup", action: confirmSchedule)
    }

    private func confirmSchedule() {
        model.confirmProviderSchedule(provider)
    }
}
