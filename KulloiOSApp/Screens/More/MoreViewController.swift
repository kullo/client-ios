/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit
import CoreGraphics
import LibKullo
import XCGLogger

class MoreViewController: UITableViewController {

    fileprivate static let moreLogoutSegueIdentifier = "MoreLogoutSegue"

    fileprivate enum SectionType {
        case avatar, settings, account, about, feedback

        var headerHeight: CGFloat {
            switch self {
            case .avatar: return CGFloat.leastNonzeroMagnitude
            default: return 10
            }
        }
    }

    // must be non-private because it is used in the cells
    enum RowType {
        case avatar
        case name, organization, footer
        case address, plan, masterKey, logout
        case version, about, website, licenses
        case feedback

        var height: CGFloat {
            return self == .avatar ? 220 : 44
        }
    }

    fileprivate struct Section {
        var type: SectionType
        var rows: [RowType]
    }

    fileprivate let sections = [
        Section(type: .avatar, rows: [.avatar]),
        Section(type: .settings, rows: [.name, .organization, .footer]),
        Section(type: .account, rows: [.address, .plan, .masterKey, .logout]),
        Section(type: .about, rows: [.version, .about, .website, .licenses]),
        Section(type: .feedback, rows: [.feedback]),
    ]

    private func indexPathForRowType(type: RowType) -> IndexPath? {
        for (sectionIndex, section) in sections.enumerated() {
            for (rowIndex, row) in section.rows.enumerated() {
                if row == type {
                    return IndexPath(row: rowIndex, section: sectionIndex)
                }
            }
        }
        return nil
    }

    // MARK: lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        tableView.reloadData()
        KulloConnector.sharedInstance.getAccountInfo { [weak self] in
            guard let indexPath = self?.indexPathForRowType(type: .plan) else { return }
            self?.tableView.reloadRows(at: [indexPath], with: .none)
        }
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

// MARK: - UITableViewDataSource
extension MoreViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]

        switch row {
        case .avatar:
            return getImageCell(tableView, indexPath: indexPath)

        case .name, .organization:
            return getEditInlineCell(tableView, indexPath: indexPath, rowType: row)

        case .address:
            let cell = getEditInlineCell(tableView, indexPath: indexPath, rowType: row)
            cell.isUserInteractionEnabled = false
            return cell

        case .footer, .plan, .masterKey, .logout, .version, .about, .website, .licenses, .feedback:
            return getActionCell(tableView, indexPath: indexPath, rowType: row)
        }
    }

    private func getImageCell(_ tableView: UITableView, indexPath: IndexPath) -> MoreImageTableViewCell {
        let cellIdentifier = "MoreImageCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! MoreImageTableViewCell
        cell.avatarImage = KulloConnector.sharedInstance.getClientAvatar()
        return cell
    }

    private func getEditInlineCell(_ tableView: UITableView, indexPath: IndexPath, rowType: RowType) -> MoreEditInlineTableViewCell {
        let cellIdentifier = "MoreEditInlineCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! MoreEditInlineTableViewCell
        cell.rowType = rowType
        return cell
    }

    private func getActionCell(_ tableView: UITableView, indexPath: IndexPath, rowType: RowType) -> MoreActionTableViewCell {
        let cellIdentifier = "MoreActionCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! MoreActionTableViewCell
        cell.rowType = rowType
        return cell
    }

}

// MARK: - UITableViewDelegate
extension MoreViewController {

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return sections[indexPath.section].rows[indexPath.row].height
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return sections[section].type.headerHeight
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let row = sections[indexPath.section].rows[indexPath.row]
        switch row {
        case .avatar:
            showAvatarActionSheet()

        case .name, .organization:
            let editInlineCell = tableView.cellForRow(at: indexPath) as! MoreEditInlineTableViewCell
            editInlineCell.cellEditContent.becomeFirstResponder()

        case .footer, .masterKey, .version, .about, .licenses:
            showDetailViewControllerForRowType(row)

        case .address:
            // do nothing on selection
            break

        case .plan:
            if let urlString = KulloConnector.sharedInstance.accountInfo?.settingsUrl,
                let url = URL(string: urlString) {
                UIApplication.shared.openURL(url)
            }

        case .logout:
            logoutClicked()

        case .website:
            UIApplication.shared.openURL(URL(string: kulloWebsiteAddress)!)

        case .feedback:
            showFeedbackDialog()
        }
    }
    
    private func showDetailViewControllerForRowType(_ rowType: RowType) {
        let detailViewControllerName: String
        switch rowType {

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

        switch rowType {
        case .footer, .masterKey:
            (detailViewController as! MoreEditTextViewController).rowType = rowType
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