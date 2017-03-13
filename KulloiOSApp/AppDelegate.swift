/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import LibKullo
import UIKit
import XCGLogger

let log: XCGLogger = {
    // manually setup logger which uses NSLog instead of print so that messages show up on production build
    let log = XCGLogger(identifier: "kulloLogger", includeDefaultDestinations: false)
    let systemDestination = AppleSystemLogDestination(owner: log)
    systemDestination.outputLevel = .debug
    systemDestination.showLogIdentifier = false
    systemDestination.showFunctionName = true
    systemDestination.showThreadName = true
    systemDestination.showLevel = true
    systemDestination.showFileName = true
    systemDestination.showLineNumber = true
    systemDestination.showDate = true
    log.add(destination: systemDestination)
    return log
}()

// Additional strings that must be translated to be shown in notifications, but are unused in code.
// These can be commented out because genstrings does also search comments for NSLocalizedString.
// NSLocalizedString("notification_title_new_message", comment: "")
// NSLocalizedString("notification_body_new_message", comment: "")

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    fileprivate var apnDeviceToken: Data?
    fileprivate let badgeManager = BadgeManager()

    //MARK: lifecycle

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // log app meta data, which also triggers lazy creation of logger
        log.logAppDetails()

        // setup libkullo
        KARegistry.setLogListener(KISystemLogLogger())
        KARegistry.setTaskRunner(KIOperationTaskRunner())
        KHRegistry.setHttpClientFactory(KIUrlSessionHttpClientFactory())

        // register for push notifications and badge updates
        application.registerUserNotificationSettings(
            UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
        )
        badgeManager.register()
        if !FeatureDetection.isRunningOnSimulator() {
            application.registerForRemoteNotifications()
        }

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

        if !FeatureDetection.isRunningOnSimulator() {
            disconnectGcm()
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.

        if !FeatureDetection.isRunningOnSimulator() {
            connectGcm()
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

        KulloConnector.sharedInstance.syncIfNecessary()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.

        if !FeatureDetection.isRunningOnSimulator() {
            stopGcm()
        }
        KulloConnector.sharedInstance.closeSession()

        // restore default log listener because we had some crashes during static deinitialization
        KARegistry.setLogListener(nil)
    }

    //MARK: push notifications

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        log.info("Registered for remote notifications, token \(deviceToken)")
        apnDeviceToken = deviceToken

        startGcm()
        refreshGcmToken()
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        log.error("Couldn't register for remote notifications: \(error)")
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        log.debug("Incoming notification (through GCM): \(userInfo)")
        GCMService.sharedInstance().appDidReceiveMessage(userInfo);
        startSync(nil)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let appState = application.applicationState
        log.debug("Incoming notification (through APN): \(userInfo); app state: \(appState)")
        GCMService.sharedInstance().appDidReceiveMessage(userInfo);
        startSync(completionHandler)
    }

    func startSync(_ completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        let task = UIApplication.shared.beginBackgroundTask()
        guard task != UIBackgroundTaskInvalid else {
            log.error("Running in the background is not possible")
            return
        }

        KulloConnector.sharedInstance.waitForSession(onSuccess: {
            KulloConnector.sharedInstance.sync(.withoutAttachments) {
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

    func startGcm() {
        let instanceIdConfig = GGLInstanceIDConfig.default()
        instanceIdConfig?.delegate = self
        GGLInstanceID.sharedInstance().start(with: instanceIdConfig)

        GCMService.sharedInstance().start(with: GCMConfig.default())
    }

    func connectGcm() {
        log.debug("GCM: connect")
        GCMService.sharedInstance().connect { error in
            if let err = error {
                log.error("Couldn't connect to GCM: \(err)")
            } else {
                log.info("Successfully connected to GCM")
            }
        }
    }

    func disconnectGcm() {
        log.debug("GCM: disconnect")
        GCMService.sharedInstance().disconnect()
    }

    func stopGcm() {
        log.debug("GCM: teardown")
        GCMService.sharedInstance().teardown()
    }

    func refreshGcmToken() {
        guard let deviceToken = apnDeviceToken else {
            log.error("Couldn't refresh Google services token, had no APN device token")
            return
        }

        GGLInstanceID.sharedInstance().token(
            withAuthorizedEntity: gcmSenderId,
            scope: kGGLInstanceIDScopeGCM,
            options: [
                kGGLInstanceIDRegisterAPNSOption: deviceToken,
                kGGLInstanceIDAPNSServerTypeSandboxOption: FeatureDetection.isRunningInPushSandbox()
            ],
            handler: { registrationToken, error in
                if let err = error {
                    log.error("Couldn't get registration token from GCM: \(err)")
                } else {
                    log.debug("GCM token: \(registrationToken)")
                    KulloConnector.sharedInstance.registerPushToken(registrationToken!)
                }
            }
        )
    }

}


extension AppDelegate: GGLInstanceIDDelegate {

    func onTokenRefresh() {
        refreshGcmToken()
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
