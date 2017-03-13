/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import LibKullo
import UIKit

class SplashViewController: UIViewController {

    private static let welcomeSegue = "SplashWelcomeSegue"
    private static let inboxSegue = "SplashInboxSegue"

    @IBOutlet weak var activityLabel: UILabel!

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        KulloConnector.sharedInstance.addSessionEventsDelegate(self)

        KulloConnector.sharedInstance.waitForSession(onSuccess: {
            self.performSegue(withIdentifier: SplashViewController.inboxSegue, sender: self)

        }, onCredentialsMissing: {
            log.debug("Could not start creating a session due to missing credentials")
            self.performSegue(withIdentifier: SplashViewController.welcomeSegue, sender: self)

        }, onError: { error in
            let alertDialog = UIAlertController(
                title: NSLocalizedString("Couldn't load data", comment: ""),
                message: error,
                preferredStyle: .alert)
            alertDialog.addAction(AlertHelper.getAlertOKAction())

            self.present(alertDialog, animated: true) {
                self.performSegue(withIdentifier: SplashViewController.welcomeSegue, sender: self)
            }
        })
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        KulloConnector.sharedInstance.removeSessionEventsDelegate(self)
    }

    @IBAction func goToSplash(_ sender: UIStoryboardSegue) {
        // Do nothing, we are already at the splash screen.
        // Used for UnwindSegues.
    }

    @IBAction func logout(_ sender: UIStoryboardSegue) {
        KulloConnector.sharedInstance.logout()

        // going to the login is handled automatically when this action has finished executing and this view is shown
    }
}

extension SplashViewController: SessionEventsDelegate {
    func sessionEventMigrationStarted() {
        activityLabel.text = NSLocalizedString("Optimizing inbox", comment: "")
    }
}
