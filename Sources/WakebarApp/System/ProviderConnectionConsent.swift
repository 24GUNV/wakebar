import Foundation
import WakebarCore

enum ProviderConnectionConsent {
    static func isAllowed(_ provider: ProviderID) -> Bool {
        UserDefaults.standard.bool(forKey: "providerConsent.v1.\(provider.rawValue)")
    }

    static func allow(_ provider: ProviderID) {
        UserDefaults.standard.set(true, forKey: "providerConsent.v1.\(provider.rawValue)")
    }
}
