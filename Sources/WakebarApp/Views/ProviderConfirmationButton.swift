import SwiftUI
import WakebarCore

struct ProviderConfirmationButton: View {
    @Bindable var model: AppModel
    let provider: ProviderID

    var body: some View {
        if model.providerDeliveryStates[provider]?.isCurrentRevisionConfirmed == true {
            Button("Mark \(provider.displayName) unconfirmed", action: clearConfirmation)
        } else {
            Button("I confirmed the \(provider.displayName) schedule", action: confirmSchedule)
        }
    }

    private func clearConfirmation() {
        model.clearProviderConfirmation(provider)
    }

    private func confirmSchedule() {
        model.confirmProviderSchedule(provider)
    }
}
