/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import UIKit
import CoreGraphics
import LibKullo

class MoreViewController: UITableViewController {

    private static let moreLeaveInboxSegueIdentifier = "MoreLeaveInboxSegue"
    private static let moreLogoutSegueIdentifier = "MoreLogoutSegue"

    private enum SectionType {
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
        case address, plan, masterKey, leaveInbox, logout
        case version, about, website, licenses
        case feedback

        var height: CGFloat {
            return self == .avatar ? 220 : 44
        }
    }

    private struct Section {
        var type: SectionType
        var rows: [RowType]
    }

    private let sections = [
        Section(type: .avatar, rows: [.avatar]),
        Section(type: .settings, rows: [.name, .organization, .footer]),
        Section(type: .account, rows: [.address, .plan, .masterKey, .leaveInbox, .logout]),
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

    override func viewDidLoad() {
        super.viewDidLoad()

        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .stop, target: self, action: #selector(closeTapped))
        navigationItem.leftBarButtonItem = closeButton
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        tableView.reloadData()
        KulloConnector.shared.getAccountInfo { [weak self] in
            guard let indexPath = self?.indexPathForRowType(type: .plan) else { return }
            self?.tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    // MARK: actions

    @objc private func closeTapped() {
        // upload potential changes to UserSettings
        KulloConnector.shared.sync(.withoutAttachments)
        navigationController?.dismiss(animated: true, completion: nil)
    }

    func leaveInboxClicked() {
        let warning = String.localizedStringWithFormat(
            NSLocalizedString("leave_inbox_warning", comment: ""),
            KulloConnector.shared.getClientAddress()
        )

        showConfirmationDialog(
            NSLocalizedString("Leave inbox?", comment: ""),
            message: warning,
            confirmationButtonText: NSLocalizedString("Leave inbox", comment: ""),
            handler: { _ in
                self.performSegue(withIdentifier: MoreViewController.moreLeaveInboxSegueIdentifier, sender: self)
            }
        )
    }

    func logoutClicked() {
        let warning = String.localizedStringWithFormat(
            NSLocalizedString("logout_warning", comment: ""),
            KulloConnector.shared.getClientAddress()
        )

        showConfirmationDialog(
            NSLocalizedString("Log out now?", comment: ""),
            message: warning,
            confirmationButtonText: NSLocalizedString("Log out and delete data", comment: ""),
            handler: { _ in
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

        case .footer, .plan, .masterKey, .leaveInbox, .logout, .version, .about, .website, .licenses, .feedback:
            return getActionCell(tableView, indexPath: indexPath, rowType: row)
        }
    }

    private func getImageCell(_ tableView: UITableView, indexPath: IndexPath) -> MoreImageTableViewCell {
        let cellIdentifier = "MoreImageCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! MoreImageTableViewCell
        cell.avatarImage = KulloConnector.shared.getClientAvatar()
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
            if let urlString = KulloConnector.shared.accountInfo?.settingsUrl,
                let url = URL(string: urlString) {
                UIApplication.shared.openURL(url)
            }

        case .leaveInbox:
            leaveInboxClicked()

        case .logout:
            logoutClicked()

        case .website:
            UIApplication.shared.openURL(URL(string: kulloWebsiteAddress)!)

        case .feedback:
            showFeedbackDialog()
        }
    }
    
    private func showDetailViewControllerForRowType(_ rowType: RowType) {
        let detailViewController: UIViewController

        switch rowType {
        case .footer, .masterKey:
            let vc = MoreEditTextViewController()
            vc.rowType = rowType
            detailViewController = vc
        case .version:
            detailViewController = StoryboardUtil.instantiate(MoreVersionsViewController.self)
        case .about:
            let storyboard = UIStoryboard(name: "MoreAboutViewController", bundle: Bundle.main)
            detailViewController = storyboard.instantiateInitialViewController()!
        case .licenses:
            detailViewController = MoreLicensesViewController()
        default:
            return
        }

        navigationController!.pushViewController(detailViewController, animated: true)
    }
    
    private func showFeedbackDialog() {
        if let navigationController = navigationController {
            let composeViewController = StoryboardUtil.instantiate(ComposeViewController.self)
            let convId = KulloConnector.shared.startConversationWithSingleRecipient(feedbackAddress)
            composeViewController.convId = convId
            navigationController.pushViewController(composeViewController, animated: true)
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
        if KulloConnector.shared.hasAvatar() {
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
        KulloConnector.shared.deleteClientAvatar()
        tableView.reloadData()
    }
}

extension MoreViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        DispatchQueue.main.async {
            let image = info[.editedImage] as! UIImage
            let croppedSquareImage = image.squareImageWithSize(CGSize(width: avatarDimension, height: avatarDimension))
            KulloConnector.shared.setClientAvatar(croppedSquareImage)
            picker.dismiss(animated: true, completion: nil)
            self.tableView.reloadData()
        }
    }
}
