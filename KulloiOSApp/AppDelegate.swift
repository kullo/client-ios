/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit

// Additional strings that must be translated to be shown in notifications, but are unused in code.
// These can be commented out because genstrings does also search comments for NSLocalizedString.
// NSLocalizedString("notification_title_new_message", comment: "")
// NSLocalizedString("notification_body_new_message", comment: "")

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var _window: UIWindow?
    private var _coordinator: AppCoordinator?
    private var _remoteNotificationManager: RemoteNotificationManager?

    //MARK: lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        setupLogger()

        let nav = UINavigationController()
        _coordinator = AppCoordinator(navigationController: nav)

        _remoteNotificationManager = RemoteNotificationManager()
        _remoteNotificationManager?.delegate = _coordinator

        UINavigationBar.appearance().tintColor = colorOrangeDark
        UIToolbar.appearance().tintColor = colorOrangeDark

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = nav
        _coordinator?.start()
        window.makeKeyAndVisible()
        _window = window

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        _remoteNotificationManager?.closeConnection()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        _remoteNotificationManager?.openConnection()
        _coordinator?.appDidBecomeActive()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        _coordinator?.shutdown()
    }

    //MARK: push notifications

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        _remoteNotificationManager?.setPushToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        log.error("Couldn't register for remote notifications: \(error)")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        log.debug("Incoming notification (through FCM): \(userInfo)")
        _remoteNotificationManager?.processNotification(userInfo: userInfo, completionHandler: nil)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let appState = application.applicationState
        log.debug("Incoming notification (through APN): \(userInfo); app state: \(appState)")
        _remoteNotificationManager?.processNotification(
            userInfo: userInfo, completionHandler: completionHandler)
    }
}
