/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import LibKullo
import UIKit

class SplashViewController: UIViewController {

    private static let welcomeSegue = "SplashWelcomeSegue"
    private static let inboxSegue = "SplashInboxSegue"

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        if KulloConnector.sharedInstance.hasSession() {
            self.performSegueWithIdentifier(SplashViewController.inboxSegue, sender: self)

        } else {
            log.debug("No session available")
            let credentialsAvailable = KulloConnector.sharedInstance.checkForStoredCredentialsAndCreateSession({
                address, error in
                if error != nil {
                    let alertDialog = UIAlertController(
                        title: NSLocalizedString("Couldn't load data", comment: ""),
                        message: error,
                        preferredStyle: .Alert)
                    alertDialog.addAction(AlertHelper.getAlertOKAction())

                    self.presentViewController(alertDialog, animated: true, completion: {
                        self.performSegueWithIdentifier(SplashViewController.welcomeSegue, sender: self)
                    })
                } else {
                    self.performSegueWithIdentifier(SplashViewController.inboxSegue, sender: self)
                }
            })
            if !credentialsAvailable {
                log.debug("Could not start creating a session")
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
