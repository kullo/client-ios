/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import UIKit
import LibKullo

class ChooseAddressViewController: UIViewController {

    private static let splashSegue = "ChooseAddressSplashSegue"
    let addressSuffix = "#kullo.net"
    var alertDialog: UIAlertController?

    @IBOutlet var usernameField: UITextField!
    @IBOutlet var registerButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        usernameField.delegate = self
    }

    @IBAction func registerTapped(sender: AnyObject) {
        alertDialog = showWaitingDialog(
            NSLocalizedString("Registering address", comment: ""),
            message: NSLocalizedString("Please wait...", comment: "")
        )

        let addressString = "\(usernameField.text ?? "")#kullo.net"
        if let address = KAAddress.create(addressString) {
            KulloConnector.sharedInstance.registerAccount(address, delegate: self)
        } else {
            showRegistrationFailure(NSLocalizedString("registration_invalid_address", comment: ""))
        }
    }

    func showRegistrationFailure(message: String) {
        alertDialog?.title = NSLocalizedString("Registration failed", comment: "")
        alertDialog?.message = message
        alertDialog?.addAction(AlertHelper.getAlertOKAction())
    }

}

extension ChooseAddressViewController : UITextFieldDelegate {

    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        let newLength = currentText.characters.count - range.length + string.characters.count
        registerButton.enabled = newLength > 0
        return true
    }

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        usernameField.resignFirstResponder()
        return false
    }

}

extension ChooseAddressViewController : RegisterAccountDelegate {

    func registerAccountChallengeNeeded(address: KAAddress, challenge: KAChallenge) {
        showRegistrationFailure(NSLocalizedString("registration_address_challenge", comment: ""))
    }

    func registerAccountAddressNotAvailable(address: KAAddress, reason: KAAddressNotAvailableReason) {
        switch reason {
        case .Blocked:
            showRegistrationFailure(NSLocalizedString("registration_address_blocked", comment: ""))
        case .Exists:
            showRegistrationFailure(NSLocalizedString("registration_address_exists", comment: ""))
        }
    }

    func registerAccountFinished(address: KAAddress, masterKey: KAMasterKey) {
        KulloConnector.sharedInstance.saveCredentials(address, masterKey: masterKey)
        alertDialog?.dismissViewControllerAnimated(true, completion: {
            self.performSegueWithIdentifier(ChooseAddressViewController.splashSegue, sender: self)
        })
    }

    func registerAccountError(error: String) {
        showRegistrationFailure(error)
    }

}
