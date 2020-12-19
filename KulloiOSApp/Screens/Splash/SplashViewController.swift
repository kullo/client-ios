/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import LibKullo
import UIKit

class SplashViewController: UIViewController {
    @IBOutlet weak var activityLabel: UILabel!

    private var forceGoingToLogin = false
    private var initialActivityLabelText: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        initialActivityLabelText = activityLabel.text
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !forceGoingToLogin else {
            forceGoingToLogin = false
            openWelcomeScreen(animated: true)
            return
        }

        KulloConnector.shared.addSessionEventsDelegate(self)

        KulloConnector.shared.waitForSession(onSuccess: {
            KulloConnector.shared.sync(.withoutAttachments)
            self.openInboxScreen(animated: true)

        }, onCredentialsMissing: {
            log.debug("Could not start creating a session due to missing credentials")
            self.openWelcomeScreen(animated: true)

        }, onError: { error in
            let alertDialog = UIAlertController(
                title: NSLocalizedString("Couldn't load data", comment: ""),
                message: error,
                preferredStyle: .alert)
            alertDialog.addAction(AlertHelper.getAlertOKAction())

            self.present(alertDialog, animated: true) {
                self.openWelcomeScreen(animated: true)
            }
        })
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        KulloConnector.shared.removeSessionEventsDelegate(self)
    }

    private func openInboxScreen(animated: Bool) {
        let vc = StoryboardUtil.instantiate(InboxViewController.self)
        let nav = UINavigationController(rootViewController: vc)
        nav.isToolbarHidden = false
        nav.modalTransitionStyle = .crossDissolve
        present(nav, animated: animated)
    }

    private func openWelcomeScreen(animated: Bool) {
        let vc = StoryboardUtil.instantiate(WelcomeViewController.self)
        let nav = PortraitNavigationController()
        nav.viewControllers = [vc]
        nav.modalTransitionStyle = .crossDissolve
        present(nav, animated: animated)
    }

    @IBAction func goToSplash(_ sender: UIStoryboardSegue) {
        // Do nothing, we are already at the splash screen.
        // Used for UnwindSegues.
    }

    @IBAction func goToLogin(_ sender: UIStoryboardSegue) {
        KulloConnector.shared.logout(deleteData: false)
        forceGoingToLogin = true
    }

    @IBAction func logout(_ sender: UIStoryboardSegue) {
        KulloConnector.shared.logout(deleteData: true)

        // going to the login is handled automatically when this action has finished executing and this view is shown
    }
}

extension SplashViewController: SessionEventsDelegate {
    func sessionEventMigrationStarted() {
        activityLabel.text = NSLocalizedString("Optimizing inbox", comment: "")
    }

    func sessionEventSessionCreated() {
        activityLabel.text = initialActivityLabelText
    }
}
