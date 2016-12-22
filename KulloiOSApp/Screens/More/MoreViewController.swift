/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import UIKit
import CoreGraphics
import XCGLogger

class MoreViewController: UIViewController {

    fileprivate static let moreLogoutSegueIdentifier = "MoreLogoutSegue"

    @IBOutlet var tableView: UITableView!

    enum Section: Int {
        case avatar, settings, account, about, feedback
    }
    let numberOfSections = 5

    let numberOfAvatarRows = 1
    let numberOfSettingsRows = 3
    let numberOfAccountRows = 3
    let numberOfAboutRows = 4
    let numberOfFeedbackRows = 1

    enum SettingsRow: Int {
        case name, organization, footer
    }

    enum AccountRow: Int {
        case address, masterKey, logout
    }

    enum AboutRow: Int {
        case version, about, website, licenses
    }

    // MARK: lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardNotifcationListenerForScrollView(tableView)
        tableView.reloadData()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        removeKeyboardNotificationListeners()
    }

    // MARK: actions

    @IBAction func dismissAndSaveChanges() {
        // upload potential changes to UserSettings
        KulloConnector.sharedInstance.sync(.withoutAttachments)
        navigationController?.dismiss(animated: true, completion: nil)
    }

    func logoutClicked() {
        showConfirmationDialog(
            NSLocalizedString("Log out now?", comment: ""),
            message: NSLocalizedString("logout_warning", comment: ""),
            confirmationButtonText: NSLocalizedString("Logout and delete data", comment: ""),
            handler: {
                (action: UIAlertAction?) in

                self.performSegue(withIdentifier: MoreViewController.moreLogoutSegueIdentifier, sender: self)
            }
        )
    }

}

extension MoreViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return numberOfSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .avatar:
            return numberOfAvatarRows
        case .settings:
            return numberOfSettingsRows
        case .account:
            return numberOfAccountRows
        case .about:
            return numberOfAboutRows
        case .feedback:
            return numberOfFeedbackRows
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell

        switch Section(rawValue: indexPath.section)! {
        case .avatar:
            cell = getImageCell(tableView, indexPath: indexPath)

        case .settings:
            switch SettingsRow(rawValue: indexPath.row)! {
            case .name:
                cell = getEditInlineCell(tableView, indexPath: indexPath, cellType: .name)
            case .organization:
                cell = getEditInlineCell(tableView, indexPath: indexPath, cellType: .organization)
            case .footer:
                cell = getActionCell(tableView, indexPath: indexPath, cellType: .footer)
            }

        case .account:
            switch AccountRow(rawValue: indexPath.row)! {
            case .address:
                cell = getEditInlineCell(tableView, indexPath: indexPath, cellType: .address)
                cell.isUserInteractionEnabled = false
            case .masterKey:
                cell = getActionCell(tableView, indexPath: indexPath, cellType: .masterKey)
            case .logout:
                cell = getActionCell(tableView, indexPath: indexPath, cellType: .logout)
            }

        case .about:
            switch AboutRow(rawValue: indexPath.row)! {
            case .version:
                cell = getActionCell(tableView, indexPath: indexPath, cellType: .version)
            case .about:
                cell = getActionCell(tableView, indexPath: indexPath, cellType: .about)
            case .website:
                cell = getActionCell(tableView, indexPath: indexPath, cellType: .website)
            case .licenses:
                cell = getActionCell(tableView, indexPath: indexPath, cellType: .licenses)
            }

        case .feedback:
            cell = getActionCell(tableView, indexPath: indexPath, cellType: .feedback)
        }
        return cell
    }

    private func getImageCell(_ tableView: UITableView, indexPath: IndexPath) -> MoreImageTableViewCell {
        let cellIdentifier = "MoreImageCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! MoreImageTableViewCell
        cell.setAvatarImage(KulloConnector.sharedInstance.getClientAvatar())
        return cell
    }

    private func getEditInlineCell(_ tableView: UITableView, indexPath: IndexPath, cellType: MoreCellType) -> MoreEditInlineTableViewCell {
        let cellIdentifier = "MoreEditInlineCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! MoreEditInlineTableViewCell
        cell.setCellType(cellType)
        return cell
    }

    private func getActionCell(_ tableView: UITableView, indexPath: IndexPath, cellType: MoreCellType) -> MoreActionTableViewCell {
        let cellIdentifier = "MoreActionCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! MoreActionTableViewCell
        cell.setCellType(cellType)
        return cell
    }

}

extension MoreViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if Section(rawValue: indexPath.section) == .avatar {
            return 220
        } else {
            return 44
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if Section(rawValue: section) == .avatar {
            return CGFloat.leastNormalMagnitude
        } else {
            return 10
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section(rawValue: indexPath.section)! {
        case .avatar:
            showAvatarActionSheet()

        case .settings:
            switch SettingsRow(rawValue: indexPath.row)! {
            case .name, .organization:
                let editInlineCell = tableView.cellForRow(at: indexPath) as! MoreEditInlineTableViewCell
                editInlineCell.cellEditContent.becomeFirstResponder()
            case .footer:
                showDetailViewControllerForMoreCellType(.footer)
            }

        case .account:
            switch AccountRow(rawValue: indexPath.row)! {
            case .address:
                // do nothing on selection
                break
            case .masterKey:
                showDetailViewControllerForMoreCellType(.masterKey)
            case .logout:
                logoutClicked()
            }

        case .about:
            switch AboutRow(rawValue: indexPath.row)! {
            case .version:
                showDetailViewControllerForMoreCellType(.version)
            case .about:
                showDetailViewControllerForMoreCellType(.about)
            case .website:
                UIApplication.shared.openURL(URL(string: kulloWebsiteAddress)!)
            case .licenses:
                showDetailViewControllerForMoreCellType(.licenses)
            }

        case .feedback:
            showFeedbackDialog()
        }
    }
    
    private func showDetailViewControllerForMoreCellType(_ cellType: MoreCellType) {
        let detailViewControllerName: String
        switch cellType {

        case .footer, .masterKey:
            detailViewControllerName = "MoreEditTextViewController"

        case .version:
            detailViewControllerName = "MoreVersionsViewController"

        case .about:
            detailViewControllerName = "MoreAboutViewController"

        case .licenses:
            detailViewControllerName = "MoreLicensesViewController"

        default:
            return
        }
        let detailViewController = storyboard!.instantiateViewController(withIdentifier: detailViewControllerName)

        switch cellType {
        case .footer, .masterKey:
            (detailViewController as! MoreEditTextViewController).cellType = cellType
        default:
            break
        }
        navigationController!.pushViewController(detailViewController, animated: true)
    }
    
    private func showFeedbackDialog() {
        if let navigationController = navigationController {
            let vc = storyboard?.instantiateViewController(withIdentifier: "ComposeViewController")

            if let composeViewController = vc as? ComposeViewController {
                let convId = KulloConnector.sharedInstance.startConversationWithSingleRecipient(feedbackAddress)
                composeViewController.convId = convId
                navigationController.pushViewController(composeViewController, animated: true)
            }
        }
    }

    private func showAvatarActionSheet() {
        let alertDialog = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alertDialog.addAction(
                UIAlertAction(
                    title: NSLocalizedString("Take a picture", comment: ""),
                    style: .default,
                    handler: { (action: UIAlertAction) in
                        self.getAvatarFromCamera()
                    }
                )
            )
        }
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            alertDialog.addAction(
                UIAlertAction(
                    title: NSLocalizedString("Choose from library", comment: ""),
                    style: .default,
                    handler: { (action: UIAlertAction) in
                        self.getAvatarFromLibrary()
                    }
                )
            )
        }
        if KulloConnector.sharedInstance.hasAvatar() {
            alertDialog.addAction(
                UIAlertAction(
                    title: NSLocalizedString("Delete avatar", comment: ""),
                    style: .destructive,
                    handler: { (action: UIAlertAction) in
                        self.deleteAvatar()
                    }
                )
            )
        }
        alertDialog.addAction(AlertHelper.getAlertCancelAction())
        present(alertDialog, animated: true, completion: nil)
    }

    private func getAvatarFromLibrary() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.allowsEditing = true

        present(imagePickerController, animated: true, completion: nil)
    }

    private func getAvatarFromCamera() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .camera
        imagePickerController.cameraCaptureMode = .photo
        imagePickerController.allowsEditing = true

        present(imagePickerController, animated: true, completion: nil)
    }

    private func deleteAvatar() {
        KulloConnector.sharedInstance.deleteClientAvatar()
        tableView.reloadData()
    }

}

extension MoreViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
        DispatchQueue.main.async {
            let image = info[UIImagePickerControllerEditedImage] as! UIImage
            let croppedSquareImage = image.squareImageWithSize(CGSize(width: avatarDimension, height: avatarDimension))
            KulloConnector.sharedInstance.setClientAvatar(croppedSquareImage)
            picker.dismiss(animated: true, completion: nil)
            self.tableView.reloadData()
        }
    }

}

enum MoreCellType {
    case image

    case name
    case organization
    case footer

    case address
    case masterKey
    case logout

    case version
    case about
    case website
    case licenses

    case feedback
}
