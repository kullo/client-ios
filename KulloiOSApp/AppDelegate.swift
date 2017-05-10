/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import Firebase
import LibKullo
import UIKit
import UserNotifications

// Additional strings that must be translated to be shown in notifications, but are unused in code.
// These can be commented out because genstrings does also search comments for NSLocalizedString.
// NSLocalizedString("notification_title_new_message", comment: "")
// NSLocalizedString("notification_body_new_message", comment: "")

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    //MARK: lifecycle

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // log app meta data, which also triggers lazy creation of logger
        log.logAppDetails()

        // setup libkullo
        KARegistry.setLogListener(KISystemLogLogger())
        KARegistry.setTaskRunner(KIOperationTaskRunner())
        KHRegistry.setHttpClientFactory(KIUrlSessionHttpClientFactory())

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onTokenRefreshNotification),
            name: Notification.Name.firInstanceIDTokenRefresh,
            object: nil)
        FIRApp.configure()

        if #available(iOS 10.0, *) {
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: {_, _ in })

            // For iOS 10 data message (sent via FCM)
            FIRMessaging.messaging().remoteMessageDelegate = self

        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }

        application.registerForRemoteNotifications()

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

        disconnectFromFcm()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

        connectToFcm()
        KulloConnector.shared.syncIfNecessary()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.

        KulloConnector.shared.closeSession()

        // restore default log listener because we had some crashes during static deinitialization
        KARegistry.setLogListener(nil)
    }

    //MARK: push notifications

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenType: FIRInstanceIDAPNSTokenType = FeatureDetection.isRunningInPushSandbox() ? .sandbox : .prod
        log.info("Registered for remote notifications, token of type \(tokenType): \(deviceToken.base64EncodedString())")

        FIRInstanceID.instanceID().setAPNSToken(deviceToken, type: tokenType)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        log.error("Couldn't register for remote notifications: \(error)")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        log.debug("Incoming notification (through FCM): \(userInfo)")
        FIRMessaging.messaging().appDidReceiveMessage(userInfo)
        startSync(nil)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let appState = application.applicationState
        log.debug("Incoming notification (through APN): \(userInfo); app state: \(appState)")
        FIRMessaging.messaging().appDidReceiveMessage(userInfo)
        startSync(completionHandler)
    }

    func startSync(_ completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        let task = UIApplication.shared.beginBackgroundTask()
        guard task != UIBackgroundTaskInvalid else {
            log.error("Running in the background is not possible")
            return
        }

        KulloConnector.shared.waitForSession(onSuccess: {
            KulloConnector.shared.sync(.withoutAttachments) {
                completionHandler?($0)
                UIApplication.shared.endBackgroundTask(task)
            }

        }, onCredentialsMissing: {
            log.warning("Could not start creating a session due to missing credentials")
            UIApplication.shared.endBackgroundTask(task)

        }, onError: { error in
            log.error("Couldn't create session: \(error)")
            UIApplication.shared.endBackgroundTask(task)
        })
    }

    func connectToFcm() {
        log.debug("FCM: connect")
        guard let firebaseToken = FIRInstanceID.instanceID().token() else { return }

        log.debug("FCM: registering token \(firebaseToken)")
        KulloConnector.shared.registerPushToken(firebaseToken)

        FIRMessaging.messaging().disconnect()
        FIRMessaging.messaging().connect { error in
            if let error = error {
                log.error("Unable to connect to FCM: \(error)")
            } else {
                log.debug("Connected to FCM.")
            }
        }
    }

    func disconnectFromFcm() {
        log.debug("FCM: disconnect")
        FIRMessaging.messaging().disconnect()
    }

    @objc private func onTokenRefreshNotification() {
        log.debug("FCM: token refresh")
        connectToFcm()
    }
}

@available(iOS 10.0, *)
extension AppDelegate: FIRMessagingDelegate {
    func applicationReceivedRemoteMessage(_ remoteMessage: FIRMessagingRemoteMessage) {
        log.debug("Incoming notification (through FCM): \(remoteMessage)")
        startSync(nil)
    }
}

extension UIApplicationState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        }
    }
}

extension FIRInstanceIDAPNSTokenType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .prod: return "prod"
        case .sandbox: return "sandbox"
        case .unknown: return "unknown"
        }
    }
}
