/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */
import Firebase
import UserNotifications

protocol RemoteNotificationManagerDelegate: class {
    func remoteNotificationUpdatedToken(fcmToken: String)
    func remoteNotificationReceivedMessage(
        data: [AnyHashable: Any], completion: ((UIBackgroundFetchResult) -> Void)?)
}

class RemoteNotificationManager: NSObject {
    weak var delegate: RemoteNotificationManagerDelegate?

    override init() {
        super.init()

        FirebaseApp.configure()

        if #available(iOS 10.0, *) {
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: {_, _ in })

            // For iOS 10 data message (sent via FCM)
            Messaging.messaging().delegate = self

        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            UIApplication.shared.registerUserNotificationSettings(settings)
        }

        UIApplication.shared.registerForRemoteNotifications()
    }

    func openConnection() {
        log.debug("FCM: connect")
        Messaging.messaging().shouldEstablishDirectChannel = true
    }

    func closeConnection() {
        log.debug("FCM: disconnect")
        Messaging.messaging().shouldEstablishDirectChannel = false
    }

    func setPushToken(_ token: Data) {
        let tokenType: MessagingAPNSTokenType =
            FeatureDetection.isRunningInPushSandbox() ? .sandbox : .prod
        log.info("Token of type \(tokenType): \(token.base64EncodedString())")
        Messaging.messaging().setAPNSToken(token, type: tokenType)
    }

    func processNotification(userInfo: [AnyHashable: Any], completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
        Messaging.messaging().appDidReceiveMessage(userInfo)
        delegate?.remoteNotificationReceivedMessage(data: userInfo, completion: completionHandler)
    }
}

extension RemoteNotificationManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        log.debug("FCM: got token \(fcmToken)")
        delegate?.remoteNotificationUpdatedToken(fcmToken: fcmToken)
    }

    func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
        log.debug("Incoming notification (through FCM): \(remoteMessage)")
        delegate?.remoteNotificationReceivedMessage(data: remoteMessage.appData, completion: nil)
    }
}
