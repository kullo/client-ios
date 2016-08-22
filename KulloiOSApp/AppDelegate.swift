/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import LibKullo
import UIKit
import XCGLogger

let log: XCGLogger = {
    // manually setup logger which uses NSLog instead of print so that messages show up on production build
    let log = XCGLogger(identifier: "kulloLogger", includeDefaultDestinations: false)
    let nslogDestination = XCGNSLogDestination(owner: log)
    nslogDestination.outputLogLevel = .Debug
    nslogDestination.showLogIdentifier = false
    nslogDestination.showFunctionName = true
    nslogDestination.showThreadName = true
    nslogDestination.showLogLevel = true
    nslogDestination.showFileName = true
    nslogDestination.showLineNumber = true
    nslogDestination.showDate = true
    log.addLogDestination(nslogDestination)
    return log
}()

// Additional strings that must be translated to be shown in notifications, but are unused in code.
// These can be commented out because genstrings does also search comments for NSLocalizedString.
// NSLocalizedString("notification_title_new_message", comment: "")
// NSLocalizedString("notification_body_new_message", comment: "")

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private var apnDeviceToken: NSData?
    private let badgeManager = BadgeManager()

    //MARK: lifecycle

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // log app meta data, which also triggers lazy creation of logger
        log.logAppDetails()

        // setup libkullo
        KARegistry.setLogListener(KISystemLogLogger())
        KARegistry.setTaskRunner(KIOperationTaskRunner())
        KHRegistry.setHttpClientFactory(KIUrlSessionHttpClientFactory())

        // register for push notifications and badge updates
        application.registerUserNotificationSettings(
            UIUserNotificationSettings(forTypes: [.Alert, .Badge, .Sound], categories: nil)
        )
        badgeManager.register()
        if !FeatureDetection.isRunningOnSimulator() {
            application.registerForRemoteNotifications()
        }

        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

        if !FeatureDetection.isRunningOnSimulator() {
            disconnectGcm()
        }
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.

        if !FeatureDetection.isRunningOnSimulator() {
            connectGcm()
        }
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

        KulloConnector.sharedInstance.syncIfNecessary()
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.

        if !FeatureDetection.isRunningOnSimulator() {
            stopGcm()
        }
        KulloConnector.sharedInstance.closeSession()

        // restore default log listener because we had some crashes during static deinitialization
        KARegistry.setLogListener(nil)
    }

    //MARK: push notifications

    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        log.info("Registered for remote notifications, token \(deviceToken)")
        apnDeviceToken = deviceToken

        startGcm()
        refreshGcmToken()
    }

    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        log.error("Couldn't register for remote notifications: \(error)")
    }

    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
        log.debug("Incoming notification (through GCM): \(userInfo)")
        GCMService.sharedInstance().appDidReceiveMessage(userInfo);
        startSync(nil)
    }

    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        let appState = application.applicationState
        log.debug("Incoming notification (through APN): \(userInfo); app state: \(appState)")
        GCMService.sharedInstance().appDidReceiveMessage(userInfo);
        startSync(completionHandler)
    }

    func startSync(completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        if KulloConnector.sharedInstance.hasSession() {
            KulloConnector.sharedInstance.sync(.WithoutAttachments, completionHandler: completionHandler)
        } else {
            KulloConnector.sharedInstance.checkForStoredCredentialsAndCreateSession { address, error in
                if error != nil {
                    log.error("Couldn't create session for \(address.toString()), will sync later: \(error)")
                }
                // call sync() even when an error occurred, so that a sync can be enqueued
                KulloConnector.sharedInstance.sync(.WithoutAttachments, completionHandler: completionHandler)
            }
        }
    }

    func startGcm() {
        let instanceIdConfig = GGLInstanceIDConfig.defaultConfig()
        instanceIdConfig.delegate = self
        GGLInstanceID.sharedInstance().startWithConfig(instanceIdConfig)

        GCMService.sharedInstance().startWithConfig(GCMConfig.defaultConfig())
    }

    func connectGcm() {
        log.debug("GCM: connect")
        GCMService.sharedInstance().connectWithHandler { (error: NSError!) -> Void in
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

        GGLInstanceID.sharedInstance().tokenWithAuthorizedEntity(
            gcmSenderId,
            scope: kGGLInstanceIDScopeGCM,
            options: [
                kGGLInstanceIDRegisterAPNSOption: deviceToken,
                kGGLInstanceIDAPNSServerTypeSandboxOption: FeatureDetection.isRunningInPushSandbox()
            ],
            handler: { (registrationToken: String!, error: NSError!) in
                if let err = error {
                    log.error("Couldn't get registration token from GCM: \(err)")
                } else {
                    log.debug("GCM token: \(registrationToken)")
                    KulloConnector.sharedInstance.registerPushToken(registrationToken)
                }
            }
        )
    }

}


extension AppDelegate : GGLInstanceIDDelegate {

    func onTokenRefresh() {
        refreshGcmToken()
    }

}

extension UIApplicationState : CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .Active: return "active"
        case .Inactive: return "inactive"
        case .Background: return "background"
        }
    }
    
}
