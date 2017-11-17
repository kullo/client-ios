/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit
import LibKullo

class LoginViewController: UIViewController {

    private static let splashSegue = "LoginSplashSegue"

    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var addressTextField: KulloAddressTextField!

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

    @IBOutlet var loginButton: UIButton!

    private var blockTextFields = [UITextField]()
    private weak var alertDialog: UIAlertController?

    private enum AddressError {
        case emptyAddress
        case invalidAddress
    }

    private struct BlocksState {
        let emptyBlocks: [Int]
        let invalidBlocks: [Int]

        var isValid: Bool {
            return emptyBlocks.isEmpty && invalidBlocks.isEmpty
        }
    }

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        blockTextFields = [
            blockATextField, blockBTextField, blockCTextField, blockDTextField,
            blockETextField, blockFTextField, blockGTextField, blockHTextField,
            blockITextField, blockJTextField, blockKTextField, blockLTextField,
            blockMTextField, blockNTextField, blockOTextField, blockPTextField,
        ]

        addressTextField.includeDefaultKulloNetCompletion = true
        addressTextField.delegate = self

        for blockTextField in blockTextFields {
            blockTextField.delegate = self
            blockTextField.addTarget(self, action: #selector(blockTextFieldEditingChanged), for: .editingChanged)
        }
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        removeKeyboardNotificationListeners()
    }

    // MARK: Login

    @IBAction func loginButtonClicked(_ sender: UIButton) {
        alertDialog = showWaitingDialog(
            NSLocalizedString("Login", comment: ""),
            message: NSLocalizedString("Please wait...", comment: "")
        )

        if validateAndShowFeedback() {
            KulloConnector.shared.checkCredentials(
                addressTextField.text!,
                masterKeyBlocks: blockTextFields.map({ $0.text ?? "" }),
                delegate: self)
        }
    }

    private func validateAndShowFeedback() -> Bool {
        var foundErrors = false

        if let addressError = validateAddress() {
            switch addressError {
            case .emptyAddress:
                alertDialog?.message = NSLocalizedString("validation_empty_address", comment: "")
            case .invalidAddress:
                alertDialog?.message = NSLocalizedString("validation_invalid_address", comment: "")
            }
            setTextFieldDesignToErrorStatus(addressTextField)
            foundErrors = true
        } else {
            setTextFieldDesignToNormalStatus(addressTextField)
        }

        let blocksState = validateBlocks()
        if !blocksState.isValid {
            if !blocksState.emptyBlocks.isEmpty {
                alertDialog?.message = NSLocalizedString("validation_empty_blocks", comment: "")
            } else if !blocksState.invalidBlocks.isEmpty {
                alertDialog?.message = NSLocalizedString("validation_invalid_blocks", comment: "")
            }
            foundErrors = true
        }

        let allBlocks = Set(blockTextFields.indices)
        let badBlocks = Set(blocksState.emptyBlocks).union(Set(blocksState.invalidBlocks))
        for badBlock in badBlocks {
            setTextFieldDesignToErrorStatus(blockTextFields[badBlock])
        }
        for goodBlock in allBlocks.subtracting(badBlocks) {
            setTextFieldDesignToNormalStatus(blockTextFields[goodBlock])
        }

        if foundErrors {
            alertDialog?.title = NSLocalizedString("Login failed", comment: "")
            alertDialog?.addAction(AlertHelper.getAlertOKAction())
        }
        return !foundErrors
    }

    private func validateAddress() -> AddressError? {
        let addressText = addressTextField.text ?? ""

        if addressText.isEmpty {
            return .emptyAddress
        }

        if !KulloConnector.isValidKulloAddress(addressText) {
            return .invalidAddress
        }

        return nil
    }

    private func validateBlocks() -> BlocksState {
        var emptyBlocks = [Int]()
        var invalidBlocks = [Int]()

        for (index, blockTextField) in zip(blockTextFields.indices, blockTextFields) {
            let blockText = blockTextField.text ?? ""

            if blockText.isEmpty {
                emptyBlocks.append(index)
            } else if !KulloConnector.isValidMasterKeyBlock(blockText) {
                invalidBlocks.append(index)
            }
        }

        return BlocksState(emptyBlocks: emptyBlocks, invalidBlocks: invalidBlocks)
    }

    // MARK: textfield on text changed

    @objc private func blockTextFieldEditingChanged(_ textField: UITextField) {
        if validateBlockFieldAndSetErrorStatus(textField) {
            focusNextBlockField(textField)
        }
    }

    private func validateBlockFieldAndSetErrorStatus(_ textField: UITextField) -> Bool {
        if textField.text?.count == 6 {
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

    private func focusNextBlockField(_ textField: UITextField) {
        let indexOfTextfield = blockTextFields.index(of: textField)!
        if indexOfTextfield < blockTextFields.count - 1 {
            blockTextFields[indexOfTextfield + 1].becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
    }

    private func setTextFieldDesignToErrorStatus(_ textField: UITextField) {
        textField.backgroundColor = colorTextFieldErrorBG
        textField.textColor = colorTextFieldErrorText
    }

    private func setTextFieldDesignToNormalStatus(_ textField: UITextField) {
        textField.backgroundColor = colorTextFieldBG
        textField.textColor = colorTextFieldText
    }

}

extension LoginViewController: UITextFieldDelegate {

    func textFieldDidBeginEditing(_ textField: UITextField) {
        setTextFieldDesignToNormalStatus(textField)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField === addressTextField {
            if !(textField.text ?? "").isEmpty && validateAddress() != nil {
                setTextFieldDesignToErrorStatus(textField)
            }
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === addressTextField {
            blockTextFields.first?.becomeFirstResponder()
        }
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // ignore change events other than character insertion and on non-MasterKey fields
        if string.isEmpty || !blockTextFields.contains(textField) {
            return true
        }

        let currentText = textField.text ?? ""
        let prospectiveText = (currentText as NSString).replacingCharacters(in: range, with: string)
        return prospectiveText.containsOnlyCharactersIn("0123456789") && prospectiveText.count <= 6
    }
}

extension LoginViewController: ClientCheckCredentialsDelegate {

    func checkCredentialsSuccess(_ address: KAAddress, masterKey: KAMasterKey) {
        KulloConnector.shared.prepareLogin(address, masterKey: masterKey)
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
