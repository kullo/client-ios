/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import LibKullo
import UIKit

class SplashViewController: UIViewController {

    private static let welcomeSegue = "SplashWelcomeSegue"
    private static let inboxSegue = "SplashInboxSegue"

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
            performSegue(withIdentifier: SplashViewController.welcomeSegue, sender: self)
            return
        }

        KulloConnector.shared.addSessionEventsDelegate(self)

        KulloConnector.shared.waitForSession(onSuccess: {
            KulloConnector.shared.sync(.withoutAttachments)
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

        KulloConnector.shared.removeSessionEventsDelegate(self)
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
