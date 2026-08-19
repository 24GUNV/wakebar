import SwiftUI
import WakebarCore

@available(iOS 26.0, *)
@main
struct WakebarPhoneApp: App {
    @UIApplicationDelegateAdaptor(PhoneAppDelegate.self) private var appDelegate
    @State private var model = PhoneCompanionRuntime.model

    var body: some Scene {
        WindowGroup {
            PhoneCompanionView(model: model)
        }
    }
}
