import UIKit

class AppCoordinator {
    private let _navigationController: UINavigationController
    private let _kulloClient: KulloConnector

    init(navigationController: UINavigationController) {
        _navigationController = navigationController

        KulloConnector.initLibrary()
        _kulloClient = KulloConnector.shared
    }

    func start() {
        let vc = StoryboardUtil.instantiate(SplashViewController.self)
        _navigationController.pushViewController(vc, animated: true)
    }

    func appDidBecomeActive() {
        _kulloClient.syncIfNecessary()
    }

    func shutdown() {
        _kulloClient.closeSession()
        KulloConnector.deinitLibrary()
    }

    func handlePushNotification(
        data: [AnyHashable : Any], completion: ((UIBackgroundFetchResult) -> Void)?) {

        let task = UIApplication.shared.beginBackgroundTask()
        guard task != UIBackgroundTaskInvalid else {
            log.error("Running in the background is not possible")
            return
        }

        _kulloClient.waitForSession(onSuccess: {
            self._kulloClient.sync(.withoutAttachments) {
                completion?($0)
                UIApplication.shared.endBackgroundTask(task)
            }

        }, onCredentialsMissing: {
            log.warning("Could not start creating a session due to missing credentials")
            completion?(.failed)
            UIApplication.shared.endBackgroundTask(task)

        }, onError: { error in
            log.error("Couldn't create session: \(error)")
            completion?(.failed)
            UIApplication.shared.endBackgroundTask(task)
        })
    }
}

extension AppCoordinator: RemoteNotificationManagerDelegate {
    func remoteNotificationUpdatedToken(fcmToken: String) {
        _kulloClient.registerPushToken(fcmToken)
    }

    func remoteNotificationReceivedMessage(
        data: [AnyHashable : Any], completion: ((UIBackgroundFetchResult) -> Void)?) {

        handlePushNotification(data: data, completion: completion)
    }
}
