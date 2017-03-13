/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit
import XCGLogger
import LibKullo

protocol NewConversationDelegate: class {
    func newConversationCreatedWithId(_ convId: Int64)
}

class NewConversationViewController: UIViewController  {

    weak var delegate: NewConversationDelegate?

    @IBOutlet var kulloAddressLabel: UILabel!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var kulloAddressTextField: KulloAddressTextField!
    @IBOutlet var recipientsLabel: UILabel!
    @IBOutlet var createButton: UIBarButtonItem!

    var recipientsAsString  = [String]()
    var recipients = [KAAddress]()

    weak var alertDialog: UIAlertController?
    
    // MARK: lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        updateControlStates()
    }
    
    // MARK: actions
    
    func updateControlStates() {
        if recipients.isEmpty {
            recipientsLabel.isHidden = true
            createButton.isEnabled = false
        } else {
            recipientsLabel.isHidden = false
            createButton.isEnabled = true
        }
    }

    @IBAction func createConversationButtonClicked(_ sender: AnyObject) {
        if recipients.count > 0 {
            let convId = KulloConnector.sharedInstance.addNewConversationForKulloAddresses(recipients)
            delegate?.newConversationCreatedWithId(convId)
            dismiss()
        }
    }
    
    @IBAction func dismiss() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func addButtonClicked(_ sender: AnyObject) {
        checkAndAddNewRecipient()
    }
    
    func checkAndAddNewRecipient() {
        kulloAddressTextField.resignFirstResponder()
        
        if let addressString = kulloAddressTextField.text {
            if addressString != "" {

                if let kulloAddress = KAAddress.create(addressString) {
                    if kulloAddress.toString() == KulloConnector.sharedInstance.getClientAddress() {
                        showInfoDialog(
                            NSLocalizedString("add_self_title", comment: ""),
                            message: NSLocalizedString("add_self_message", comment: "")
                        )
                        log.info("Tried to add local user to conversation")

                    } else {
                        alertDialog = showWaitingDialog(
                            NSLocalizedString("Adding recipient", comment: ""),
                            message: NSLocalizedString("Checking if address exists...", comment: "")
                        )
                        KulloConnector.sharedInstance.checkIfAddressExists(kulloAddress, delegate: self)
                    }

                } else {
                    showInfoDialog(
                        NSLocalizedString("Invalid address", comment: ""),
                        message: NSLocalizedString("The entered address is invalid.", comment: "")
                    )
                    log.info("Tried to add recipient with invalid address")
                }

            } else {
                showInfoDialog(
                    NSLocalizedString("Address field empty", comment: ""),
                    message: NSLocalizedString("Please enter an address.", comment: "")
                )
                log.info("Tried to add recipient with empty address field")
            }
        }
    }

}

extension NewConversationViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recipients.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")!
        cell.textLabel?.text = recipients[indexPath.row].toString()
        return cell
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            recipients.remove(at: indexPath.row)
            recipientsAsString.remove(at: indexPath.row)
            updateControlStates()
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

}

extension NewConversationViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        checkAndAddNewRecipient()
        return true
    }

}

extension NewConversationViewController: ClientAddressExistsDelegate {

    func clientAddressExistsFinished(_ address: KAAddress, exists: Bool) {
        if exists {
            if !recipientsAsString.contains(address.toString()) {
                alertDialog?.dismiss(animated: true, completion: { () -> Void in
                    self.recipientsAsString.append(address.toString())
                    self.recipients.append(address)
                    self.kulloAddressTextField.text = ""
                    self.tableView.reloadData()
                    self.updateControlStates()
                    self.kulloAddressTextField.becomeFirstResponder()
                })
            } else {
                if let alertDialog = alertDialog {
                    alertDialog.title = NSLocalizedString("Already added", comment: "")
                    alertDialog.message = NSLocalizedString("You have already added this recipient to the new conversation", comment: "")
                    alertDialog.addAction(AlertHelper.getAlertOKAction({
                        (UIAlertAction) in
                        self.kulloAddressTextField.becomeFirstResponder()
                    }))
                }
                log.info("Recipient already in list")
            }

        } else {
            if let alertDialog = alertDialog {
                alertDialog.title = NSLocalizedString("Recipient unknown", comment: "")
                alertDialog.message = NSLocalizedString("We could not find a recipient with this address.", comment: "")
                alertDialog.addAction(AlertHelper.getAlertOKAction({
                    (UIAlertAction) in
                    self.kulloAddressTextField.becomeFirstResponder()
                }))
            }
            log.info("Recipient unknown")
        }
    }

    func clientAddressExistsError(_ address: KAAddress, error: String) {
        if let alertDialog = alertDialog {
            alertDialog.title = NSLocalizedString("Error checking address", comment: "")
            alertDialog.message = error
            alertDialog.addAction(AlertHelper.getAlertOKAction())
        }
        log.info("Error checking address: \(error)")
    }

}
