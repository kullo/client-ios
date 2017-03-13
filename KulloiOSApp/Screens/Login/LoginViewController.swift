/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit
import LibKullo

class LoginViewController: UIViewController, UITextFieldDelegate {

    fileprivate static let splashSegue = "LoginSplashSegue"

    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var addressLabel: UILabel!
    @IBOutlet var addressTextField: UITextField!

    @IBOutlet var blockATextField: UITextField!
    @IBOutlet var blockBTextField: UITextField!
    @IBOutlet var blockCTextField: UITextField!
    @IBOutlet var blockDTextField: UITextField!
    @IBOutlet var blockETextField: UITextField!
    @IBOutlet var blockFTextField: UITextField!
    @IBOutlet var blockGTextField: UITextField!
    @IBOutlet var blockHTextField: UITextField!
    @IBOutlet var blockITextField: UITextField!
    @IBOutlet var blockJTextField: UITextField!
    @IBOutlet var blockKTextField: UITextField!
    @IBOutlet var blockLTextField: UITextField!
    @IBOutlet var blockMTextField: UITextField!
    @IBOutlet var blockNTextField: UITextField!
    @IBOutlet var blockOTextField: UITextField!
    @IBOutlet var blockPTextField: UITextField!

    @IBOutlet var registerButton: UIButton!
    @IBOutlet var loginButton: UIButton!

    fileprivate var blockTextFields = [UITextField]()
    fileprivate weak var alertDialog: UIAlertController?

    enum CredentialsError {
        case emptyAddress
        case invalidAddress
        case emptyBlocks
        case invalidBlock
    }

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        addBlockTextFieldsToArray()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardNotifcationListenerForScrollView(scrollView)
        if let address = testingPrefillAddress, let masterKey = testingPrefillMasterKey {
            addressTextField.text = address
            for blockAndTextField in zip(masterKey, blockTextFields) {
                blockAndTextField.1.text = blockAndTextField.0
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        removeKeyboardNotificationListeners()
    }

    // MARK: Login

    @IBAction func loginButtonClicked(_ sender: UIButton) {
        alertDialog = showWaitingDialog(
            NSLocalizedString("Login", comment: ""),
            message: NSLocalizedString("Please wait...", comment: "")
        )

        if inputFieldsAreValidIfNotGiveUserFeedback() {
            KulloConnector.sharedInstance.checkCredentials(
                addressTextField.text!,
                masterKeyBlocks: getKeyBlocksAsStringArray(),
                delegate: self)
        }
    }

    func inputFieldsAreValidIfNotGiveUserFeedback() -> Bool {
        let okAction = AlertHelper.getAlertOKAction()

        if let error = validateInputFields() {
            alertDialog?.title = NSLocalizedString("Login failed", comment: "")
            alertDialog?.addAction(okAction)

            switch error {
            case .emptyAddress:
                alertDialog?.message = NSLocalizedString("validation_empty_address", comment: "")
                return false
            case .invalidAddress:
                alertDialog?.message = NSLocalizedString("validation_invalid_address", comment: "")
                return false
            case .emptyBlocks:
                alertDialog?.message = NSLocalizedString("validation_empty_blocks", comment: "")
                return false
            case .invalidBlock:
                alertDialog?.message = NSLocalizedString("validation_invalid_blocks", comment: "")
                return false
            }
        }

        return true
    }

    func validateInputFields() -> CredentialsError? {
        let addressText = addressTextField.text ?? ""

        if addressText.isEmpty {
            setTextFieldDesignToErrorStatus(addressTextField)
            return CredentialsError.emptyAddress
        }

        if !KulloConnector.isValidKulloAddress(addressText) {
            setTextFieldDesignToErrorStatus(addressTextField)
            return CredentialsError.invalidAddress
        }

        setTextFieldDesignToNormalStatus(addressTextField)

        var invalidBlock = false
        var emptyBlock = false

        for blockTextField in blockTextFields {
            let blockText = blockTextField.text ?? ""

            if blockText.isEmpty {
                emptyBlock = true
                setTextFieldDesignToErrorStatus(blockTextField)

            } else if !KulloConnector.isValidMasterKeyBlock(blockText) {
                invalidBlock = true
                setTextFieldDesignToErrorStatus(blockTextField)

            } else {
                setTextFieldDesignToNormalStatus(blockTextField)
            }
        }

        if emptyBlock {
            return CredentialsError.emptyBlocks
        }
        if invalidBlock {
            return CredentialsError.invalidBlock
        }
        return nil
    }

    func getKeyBlocksAsStringArray() -> [String] {
        var blockArray: [String] = []

        for blockTextField in blockTextFields {
            blockArray.append(blockTextField.text!)
        }

        return blockArray
    }

    // MARK: UI

    func addBlockTextFieldsToArray() {
        blockTextFields.append(blockATextField)
        blockTextFields.append(blockBTextField)
        blockTextFields.append(blockCTextField)
        blockTextFields.append(blockDTextField)
        blockTextFields.append(blockETextField)
        blockTextFields.append(blockFTextField)
        blockTextFields.append(blockGTextField)
        blockTextFields.append(blockHTextField)
        blockTextFields.append(blockITextField)
        blockTextFields.append(blockJTextField)
        blockTextFields.append(blockKTextField)
        blockTextFields.append(blockLTextField)
        blockTextFields.append(blockMTextField)
        blockTextFields.append(blockNTextField)
        blockTextFields.append(blockOTextField)
        blockTextFields.append(blockPTextField)
    }

    // MARK: UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === addressTextField {
            blockTextFields.first?.becomeFirstResponder()
        }
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool
    {
        //igore change events other than character insertion and on non-MasterKey fields
        if string.characters.count == 0 || !blockTextFields.contains(textField) {
            return true
        }

        let currentText = textField.text ?? ""
        let prospectiveText = (currentText as NSString).replacingCharacters(in: range, with: string)
        return prospectiveText.containsOnlyCharactersIn("0123456789") && prospectiveText.characters.count <= 6
    }

    // MARK: textfield on text changed

    @IBAction func textfieldEditingChanged(_ textField: UITextField) {
        if textField === addressTextField {
            setTextFieldDesignToNormalStatus(textField)

        } else if blockTextFields.contains(textField) {
            if validateBlockFieldAndSetErrorStatus(textField) {
                focusNextBlockField(textField)
            }
        }
    }

    func validateBlockFieldAndSetErrorStatus(_ textField: UITextField) -> Bool {
        if textField.text?.characters.count == 6 {
            if KulloConnector.isValidMasterKeyBlock(textField.text!) {
                setTextFieldDesignToNormalStatus(textField)
                return true
            } else {
                setTextFieldDesignToErrorStatus(textField)
                return false
            }
        } else {
            setTextFieldDesignToNormalStatus(textField)
            return false
        }
    }

    func focusNextBlockField(_ textField: UITextField) {
        let indexOfTextfield = blockTextFields.index(of: textField)!
        if indexOfTextfield < blockTextFields.count - 1 {
            blockTextFields[indexOfTextfield + 1].becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
    }

    func setTextFieldDesignToErrorStatus(_ textField: UITextField) {
        textField.backgroundColor = colorTextFieldErrorBG
        textField.textColor = colorTextFieldErrorText
    }

    func setTextFieldDesignToNormalStatus(_ textField: UITextField) {
        textField.backgroundColor = colorTextFieldBG
        textField.textColor = colorTextFieldText
    }

}

extension LoginViewController: ClientCheckCredentialsDelegate {

    func checkCredentialsSuccess(_ address: KAAddress, masterKey: KAMasterKey) {
        KulloConnector.sharedInstance.saveCredentials(address, masterKey: masterKey)
        clearInputFields()

        alertDialog?.dismiss(animated: true, completion: {
            self.performSegue(withIdentifier: LoginViewController.splashSegue, sender: self)
        })
    }

    func checkCredentialsInvalid(_ address: KAAddress, masterKey: KAMasterKey) {
        alertDialog?.title = NSLocalizedString("Login failed", comment: "")
        alertDialog?.message = NSLocalizedString("Couldn't log in with the given Kullo address and MasterKey.", comment: "")
        alertDialog?.addAction(AlertHelper.getAlertOKAction())
    }

    func checkCredentialsError(_ error: String) {
        alertDialog?.title = NSLocalizedString("Login failed", comment: "")
        alertDialog?.message = error
        alertDialog?.addAction(AlertHelper.getAlertOKAction())
    }

    func clearInputFields() {
        addressTextField.text = ""

        for blockTextField in blockTextFields {
            blockTextField.text = ""
        }
    }

}
