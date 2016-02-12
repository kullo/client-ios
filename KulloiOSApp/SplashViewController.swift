/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import LibKullo
import UIKit

class SplashViewController: UIViewController {

    private static let welcomeSegue = "SplashWelcomeSegue"
    private static let inboxSegue = "SplashInboxSegue"

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if !KulloConnector.sharedInstance.hasSession() {
            if !KulloConnector.sharedInstance.checkForStoredCredentialsAndCreateSession(self) {
                performSegueWithIdentifier(SplashViewController.welcomeSegue, sender: self)
            }
        }
    }

    @IBAction func goToSplash(sender: UIStoryboardSegue) {
        // Do nothing, we are already at the splash screen.
        // Used for UnwindSegues.
    }

    @IBAction func logout(sender: UIStoryboardSegue) {
        KulloConnector.sharedInstance.logout()

        // going to the login is handled automatically when this action has finished executing and this view is shown
    }

}

// MARK: ClientCreateSessionDelegate

extension SplashViewController : ClientCreateSessionDelegate {

    func createSessionFinished(session: KASession) {
        KulloConnector.sharedInstance.setSession(session)
        performSegueWithIdentifier(SplashViewController.inboxSegue, sender: self)
    }

    func createSessionError(address: KAAddress, error: String) {
        let alertDialog = UIAlertController(
            title: NSLocalizedString("Couldn't load data", comment: ""),
            message: error,
            preferredStyle: .Alert)
        alertDialog.addAction(AlertHelper.getAlertOKAction())

        presentViewController(alertDialog, animated: true, completion: {
            self.performSegueWithIdentifier(SplashViewController.welcomeSegue, sender: self)
        })
    }

}
