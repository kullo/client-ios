/* Copyright 2015 Kullo GmbH. All rights reserved. */

import UIKit
import CoreGraphics
import XCGLogger

class MoreViewController: UIViewController {

    private static let moreLogoutSegueIdentifier = "MoreLogoutSegue"

    @IBOutlet var tableView: UITableView!

    enum Section: Int {
        case Avatar, Settings, Logout, About, Feedback
    }
    let numberOfSections = 5

    let numberOfAvatarRows = 1
    let numberOfSettingsRows = 3
    let numberOfLogoutRows = 1
    let numberOfAboutRows = 4
    let numberOfFeedbackRows = 1

    enum SettingsRow: Int {
        case Name, Organization, Footer
    }

    enum AboutRow: Int {
        case Version, About, Website, Licenses
    }

    // MARK: lifecycle

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardNotifcationListenerForScrollView(tableView)
        tableView.reloadData()
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)

        removeKeyboardNotificationListeners()
    }

    // MARK: actions

    @IBAction func dismissAndSaveChanges() {
        KulloConnector.sharedInstance.storeCurrentUserSettings()

        navigationController?.dismissViewControllerAnimated(true, completion: nil)
    }

    func logoutClicked() {
        showConfirmationDialog(
            NSLocalizedString("Log out now?", comment: ""),
            message: NSLocalizedString("logout_warning", comment: ""),
            confirmationButtonText: NSLocalizedString("Logout and delete data", comment: ""),
            handler: {
                (action: UIAlertAction!) in

                self.performSegueWithIdentifier(MoreViewController.moreLogoutSegueIdentifier, sender: self)
            }
        )
    }

}

extension MoreViewController : UITableViewDataSource {

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return numberOfSections
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .Avatar:
            return numberOfAvatarRows
        case .Settings:
            return numberOfSettingsRows
        case .Logout:
            return numberOfLogoutRows
        case .About:
            return numberOfAboutRows
        case .Feedback:
            return numberOfFeedbackRows
        }
    }

    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if Section(rawValue: indexPath.section) == .Avatar {
            return 220
        } else {
            return 44
        }
    }

    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if Section(rawValue: section) == .Avatar {
            return CGFloat.min
        } else {
            return 10
        }
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell

        switch Section(rawValue: indexPath.section)! {
        case .Avatar:
            cell = getImageCell(tableView, indexPath: indexPath)

        case .Settings:
            switch SettingsRow(rawValue: indexPath.row)! {
            case .Name:
                cell = getEditInlineCell(tableView, indexPath: indexPath, cellType: .Name)
            case .Organization:
                cell = getEditInlineCell(tableView, indexPath: indexPath, cellType: .Organization)
            case .Footer:
                cell = getActionCell(tableView, indexPath: indexPath, cellType: .Footer)
            }

        case .Logout:
            cell = getActionCell(tableView, indexPath: indexPath, cellType: .Logout)
            
        case .About:
            switch AboutRow(rawValue: indexPath.row)! {
            case .Version:
                cell = getActionCell(tableView, indexPath: indexPath, cellType: .Version)
            case .About:
                cell = getActionCell(tableView, indexPath: indexPath, cellType: .About)
            case .Website:
                cell = getActionCell(tableView, indexPath: indexPath, cellType: .Website)
            case .Licenses:
                cell = getActionCell(tableView, indexPath: indexPath, cellType: .Licenses)
            }

        case .Feedback:
            cell = getActionCell(tableView, indexPath: indexPath, cellType: .Feedback)
        }
        return cell
    }

    func getImageCell(tableView: UITableView, indexPath: NSIndexPath) -> MoreImageTableViewCell {
        let cellIdentifier = "MoreImageCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! MoreImageTableViewCell
        cell.setAvatarImage(KulloConnector.sharedInstance.getClientAvatar())
        return cell
    }

    func getEditInlineCell(tableView: UITableView, indexPath: NSIndexPath, cellType: MoreCellType) -> MoreEditInlineTableViewCell {
        let cellIdentifier = "MoreEditInlineCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! MoreEditInlineTableViewCell
        cell.setCellType(cellType)
        return cell
    }

    func getActionCell(tableView: UITableView, indexPath: NSIndexPath, cellType: MoreCellType) -> MoreActionTableViewCell {
        let cellIdentifier = "MoreActionCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! MoreActionTableViewCell
        cell.setCellType(cellType)
        return cell
    }

}

extension MoreViewController : UITableViewDelegate {

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)

        switch Section(rawValue: indexPath.section)! {
        case .Avatar:
            showAvatarActionSheet()

        case .Settings:
            switch SettingsRow(rawValue: indexPath.row)! {
            case .Name, .Organization:
                let editInlineCell = tableView.cellForRowAtIndexPath(indexPath) as! MoreEditInlineTableViewCell
                editInlineCell.cellEditContent.becomeFirstResponder()
            case .Footer:
                showDetailViewControllerForMoreCellType(.Footer)
            }

        case .Logout:
            logoutClicked()

        case .About:
            switch AboutRow(rawValue: indexPath.row)! {
            case .Version:
                showDetailViewControllerForMoreCellType(.Version)
            case .About:
                showDetailViewControllerForMoreCellType(.About)
            case .Website:
                UIApplication.sharedApplication().openURL(NSURL(string: kulloWebsiteAddress)!)
            case .Licenses:
                showDetailViewControllerForMoreCellType(.Licenses)
            }

        case .Feedback:
            showFeedbackDialog()
        }
    }
    
    func showDetailViewControllerForMoreCellType(cellType: MoreCellType) {
        let detailViewControllerName: String
        switch cellType {

        case .Footer:
            detailViewControllerName = "MoreEditTextViewController"

        case .Version:
            detailViewControllerName = "MoreVersionsViewController"

        case .About:
            detailViewControllerName = "MoreAboutViewController"

        case .Licenses:
            detailViewControllerName = "MoreLicensesViewController"

        default:
            return
        }
        let detailViewController = storyboard!.instantiateViewControllerWithIdentifier(detailViewControllerName)

        if cellType == .Footer {
            (detailViewController as! MoreEditTextViewController).cellType = .Footer
        }
        navigationController!.pushViewController(detailViewController, animated: true)
    }
    
    func showFeedbackDialog() {
        if let navigationController = navigationController {
            let vc = storyboard?.instantiateViewControllerWithIdentifier("ComposeViewController")

            if let composeViewController = vc as? ComposeViewController {
                let convId = KulloConnector.sharedInstance.startConversationWithSingleRecipient(feedbackAddress)
                composeViewController.convId = convId
                navigationController.pushViewController(composeViewController, animated: true)
            }
        }
    }

    func showAvatarActionSheet() {
        let alertDialog = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)

        if UIImagePickerController.isSourceTypeAvailable(.Camera) {
            alertDialog.addAction(
                UIAlertAction(
                    title: NSLocalizedString("Take a picture", comment: ""),
                    style: .Default,
                    handler: { (action: UIAlertAction) in
                        self.getAvatarFromCamera()
                    }
                )
            )
        }
        if UIImagePickerController.isSourceTypeAvailable(.PhotoLibrary) {
            alertDialog.addAction(
                UIAlertAction(
                    title: NSLocalizedString("Choose from library", comment: ""),
                    style: .Default,
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
                    style: .Destructive,
                    handler: { (action: UIAlertAction) in
                        self.deleteAvatar()
                    }
                )
            )
        }
        alertDialog.addAction(AlertHelper.getAlertCancelAction())
        presentViewController(alertDialog, animated: true, completion: nil)
    }

    func getAvatarFromLibrary() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .PhotoLibrary
        imagePickerController.allowsEditing = true

        presentViewController(imagePickerController, animated: true, completion: nil)
    }

    func getAvatarFromCamera() {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .Camera
        imagePickerController.cameraCaptureMode = .Photo
        imagePickerController.allowsEditing = true

        presentViewController(imagePickerController, animated: true, completion: nil)
    }

    func deleteAvatar() {
        KulloConnector.sharedInstance.deleteClientAvatar()
        tableView.reloadData()
    }

}

extension MoreViewController : UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        dispatch_async(dispatch_get_main_queue()) {
            let image = info[UIImagePickerControllerEditedImage] as! UIImage
            let croppedSquareImage = image.squareImageWithSize(CGSizeMake(avatarDimension, avatarDimension))
            KulloConnector.sharedInstance.setClientAvatar(croppedSquareImage)
            picker.dismissViewControllerAnimated(true, completion: nil)
            self.tableView.reloadData()
        }
    }

}

enum MoreCellType {
    case Undefined
    
    case Image
    
    case Name
    case Organization
    case Footer
    
    case Logout

    case Version
    case About
    case Website
    case Licenses

    case Feedback
}
