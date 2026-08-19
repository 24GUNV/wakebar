import UIKit

@available(iOS 26.0, *)
@MainActor
final class PhoneAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        _ = launchOptions
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        _ = application
        _ = deviceToken
        PhoneCompanionRuntime.model.markRemoteNotificationsRegistered()
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        _ = application
        PhoneCompanionRuntime.model.markRemoteNotificationsFailed(error.localizedDescription)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        _ = application
        _ = userInfo
        Task { @MainActor in
            let result = await PhoneCompanionRuntime.model.refreshFromBackground()
            switch result {
            case .newData:
                completionHandler(.newData)
            case .noData:
                completionHandler(.noData)
            case .failed:
                completionHandler(.failed)
            }
        }
    }
}
