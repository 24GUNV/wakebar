import Foundation
import WakebarCore

struct ProviderSetupRequest: Identifiable, Equatable {
    let id = UUID()
    let provider: ProviderID
    let purpose: ProviderSetupPurpose
}
