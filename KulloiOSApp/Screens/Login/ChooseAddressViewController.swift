/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import UIKit
import LibKullo

class ChooseAddressViewController: UIViewController {

    private static let linkRegex = try! NSRegularExpression(pattern: "(\\[.*\\])", options: [])
    private static let splashSegue = "ChooseAddressSplashSegue"

    let addressSuffix = "#kullo.net"
    var alertDialog: UIAlertController?

    private var registerButton: UIBarButtonItem!
    @IBOutlet var usernameField: UITextField!
    @IBOutlet var termsLabel: UILabel!
    @IBOutlet var termsAcceptedSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()

        registerButton = UIBarButtonItem(
            title: NSLocalizedString("Register", comment: ""), style: .plain,
            target: self, action: #selector(registerTapped))
        navigationItem.rightBarButtonItem = registerButton
        updateRegisterButtonState()

        usernameField.delegate = self
        loadTermsLabelText()
    }

    private func loadTermsLabelText() {
        let text = NSMutableAttributedString(string: NSLocalizedString("accept_terms", comment: ""))

        if let match = ChooseAddressViewController.linkRegex.firstMatch(
            in: text.string,
            options: [],
            range: NSRange(location: 0, length: text.length)) {

            let substringRangeWithoutBrackets = NSRange(
                location: match.range.location + 1,
                length: match.range.length - 2)

            let linkText = NSMutableAttributedString(
                attributedString: text.attributedSubstring(from: substringRangeWithoutBrackets))
            linkText.addAttribute(
                .foregroundColor,
                value: colorAccent,
                range: NSRange(location: 0, length: linkText.length))

            text.replaceCharacters(in: match.range, with: linkText)
        }
        termsLabel.attributedText = text
    }

    @IBAction func usernameChanged(_ sender: UITextField) {
        updateRegisterButtonState()
    }

    @IBAction func backgroundTapped(_ sender: UITapGestureRecognizer) {
        view.endEditing(true)
    }

    @IBAction func termsTapped(_ sender: UITapGestureRecognizer) {
        UIApplication.shared.openURL(URL(string: kulloTermsAndConditions)!)
    }

    @IBAction func termsAcceptedChanged(_ sender: UISwitch) {
        updateRegisterButtonState()
    }

    @objc private func registerTapped() {
        alertDialog = showWaitingDialog(
            NSLocalizedString("Registering address", comment: ""),
            message: NSLocalizedString("Please wait...", comment: "")
        )

        let addressString = "\(usernameField.text ?? "")#kullo.net"
        if let address = KAAddressHelpers.create(addressString) {
            KulloConnector.shared.registerAccount(address, delegate: self)
        } else {
            showRegistrationFailure(NSLocalizedString("registration_invalid_address", comment: ""))
        }
    }

    private func showRegistrationFailure(_ message: String) {
        alertDialog?.title = NSLocalizedString("Registration failed", comment: "")
        alertDialog?.message = message
        alertDialog?.addAction(AlertHelper.getAlertOKAction())
    }

    private func updateRegisterButtonState() {
        let usernameEmpty = usernameField.text?.isEmpty ?? true
        registerButton.isEnabled = termsAcceptedSwitch.isOn && !usernameEmpty
    }
}

extension ChooseAddressViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        usernameField.resignFirstResponder()
        return false
    }
}

extension ChooseAddressViewController: RegisterAccountDelegate {

    func registerAccountChallengeNeeded(_ address: KAAddress, challenge: KAChallenge) {
        showRegistrationFailure(NSLocalizedString("registration_address_challenge", comment: ""))
    }

    func registerAccountAddressNotAvailable(_ address: KAAddress, reason: KAAddressNotAvailableReason) {
        switch reason {
        case .blocked:
            showRegistrationFailure(NSLocalizedString("registration_address_blocked", comment: ""))
        case .exists:
            showRegistrationFailure(NSLocalizedString("registration_address_exists", comment: ""))
        }
    }

    func registerAccountFinished(_ address: KAAddress, masterKey: KAMasterKey) {
        KulloConnector.shared.prepareLogin(address, masterKey: masterKey)
        alertDialog?.dismiss(animated: true, completion: {
            self.performSegue(withIdentifier: ChooseAddressViewController.splashSegue, sender: self)
        })
    }

    func registerAccountError(_ error: String) {
        showRegistrationFailure(error)
    }
}
