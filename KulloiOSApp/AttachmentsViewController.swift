/* Copyright 2015 Kullo GmbH. All rights reserved. */

import UIKit
import CoreGraphics
import XCGLogger

class AttachmentsViewController: UIViewController, MessageAttachmentsSaveToDelegate {

    @IBOutlet var tableView: UITableView!
    @IBOutlet var downloadBarButtonItem: UIBarButtonItem!

    var messageId: Int64?
    private var attachmentIds = [Int64]()
    private var attachmentsAreDownloaded: Bool = false

    private weak var alertDialog: UIAlertController?
    private var documentInteractionController = UIDocumentInteractionController()

    // MARK: lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        documentInteractionController.delegate = self
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        updateDataAndRefreshUI()
    }

    // MARK: actions

    @IBAction func dismiss() {
        navigationController!.dismissViewControllerAnimated(true, completion: nil)
    }

    // MARK: download

    @IBAction func download() {
        alertDialog = showWaitingDialog(
            NSLocalizedString("Downloading attachments", comment: ""),
            message: NSLocalizedString("Please wait...", comment: "")
        )

        KulloConnector.sharedInstance.addSyncDelegate(self)
        KulloConnector.sharedInstance.downloadAttachments(messageId!)
    }

    // MARK: Data

    func updateDataAndRefreshUI() {
        if let messageId = messageId {
            attachmentsAreDownloaded = KulloConnector.sharedInstance.getMessageAttachmentsDownloaded(messageId)
            attachmentIds = KulloConnector.sharedInstance.getMessageAttachmentsIds(messageId)

            updateUIDependingOnDownloadState()
            tableView.reloadData()
        }
    }

    func updateUIDependingOnDownloadState() {
        if attachmentsAreDownloaded {
            downloadBarButtonItem.enabled = false
            downloadBarButtonItem.title = ""
        }
    }

    // MARK: open attachment

    func openAttachment(attachmentId: Int64) {
        alertDialog = showWaitingDialog(
            NSLocalizedString("Opening file", comment: ""),
            message: NSLocalizedString("Please wait...", comment: "")
        )

        let filename = KulloConnector.sharedInstance.getMessageAttachmentFilename(messageId!, attachmentId: attachmentId)

        if fileExistsInTempDirectory(filename) {
            alertDialog?.dismissViewControllerAnimated(true, completion: {
                self.useDICToOpenFile(self.getFilePathInTempDirectory(filename))
            })
        } else {
            let path = getFilePathInTempDirectory(filename)
            KulloConnector.sharedInstance.saveMessageAttachment(messageId!, attachmentId: attachmentId, path: path, delegate: self)
        }
    }

    func fileExistsInTempDirectory(filename: String) -> Bool {
        let path = getFilePathInTempDirectory(filename)
        return NSFileManager.defaultManager().fileExistsAtPath(path)
    }

    func getTempDir() -> String {
        return NSTemporaryDirectory().stringByAppendingString("kullo_temp/")
    }

    func getFilePathInTempDirectory(filename: String) -> String {
        let tempDir = getTempDir()
        do {
            try NSFileManager.defaultManager().createDirectoryAtPath(tempDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            log.error("Could not create temp directory to save file: \(filename)")
            return ""
        }
        return tempDir.stringByAppendingString(filename)
    }

    func messageAttachmentsSaveToFinished(msgId: Int64, attId: Int64, path: String) {
        alertDialog?.dismissViewControllerAnimated(true, completion: {
            self.useDICToOpenFile(path)
        })
    }

    func messageAttachmentsSaveToError(msgId: Int64, attId: Int64, path: String, error: String) {
        if let alertDialog = alertDialog {
            alertDialog.title = NSLocalizedString("Error opening file", comment: "")
            alertDialog.message = error
            alertDialog.addAction(AlertHelper.getAlertOKAction())
        }
    }

    func useDICToOpenFile(path: String) {
        log.info("File temp save successfully, opening with DIC, path: \(path)")
        documentInteractionController.URL = NSURL(fileURLWithPath: path)
        documentInteractionController.presentPreviewAnimated(true)
    }

}

extension AttachmentsViewController : UITableViewDataSource {
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return attachmentIds.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellIdentifier = "AttachmentTableViewCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! AttachmentTableViewCell

        let attachmentId = attachmentIds[indexPath.row]

        cell.attachmentTitleLabel.text = KulloConnector.sharedInstance.getMessageAttachmentFilename(messageId!, attachmentId: attachmentId)

        if attachmentsAreDownloaded {
            cell.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
            cell.selectionStyle = UITableViewCellSelectionStyle.Gray
            cell.attachmentTitleLabel.textColor = UIColor.darkTextColor()
        } else {
            cell.selectionStyle = UITableViewCellSelectionStyle.None
            cell.attachmentTitleLabel.textColor = UIColor.darkGrayColor()
        }

        return cell
    }

}

extension AttachmentsViewController : UITableViewDelegate {

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)

        if attachmentsAreDownloaded {
            let attachmentId = attachmentIds[indexPath.row]
            openAttachment(attachmentId)
        }
    }

}

extension AttachmentsViewController : SyncDelegate {

    // MARK: sync delegate

    func syncErrorDraftAttachmentsTooBig(convId: Int64) {
        if let alertDialog = alertDialog {
            alertDialog.title = NSLocalizedString("Attachments too big", comment: "")
            alertDialog.message = NSLocalizedString("Attachments at one conversation are too big.", comment: "")
            alertDialog.addAction(AlertHelper.getAlertOKAction())
        }
        KulloConnector.sharedInstance.removeSyncDelegate(self)
    }

    func syncFinished() {
        log.info("Sync finished successfully, attachments are downloaded.");
        alertDialog?.dismissViewControllerAnimated(true, completion: { () -> Void in
            self.updateDataAndRefreshUI()
        })
        KulloConnector.sharedInstance.removeSyncDelegate(self)
    }

    func syncError(error: String) {
        if let alertDialog = alertDialog {
            alertDialog.title = NSLocalizedString("Synchronization error", comment: "")
            alertDialog.message = error
            alertDialog.addAction(AlertHelper.getAlertOKAction())
        }
        KulloConnector.sharedInstance.removeSyncDelegate(self)
    }

}

extension AttachmentsViewController : UIDocumentInteractionControllerDelegate {

    func documentInteractionControllerViewControllerForPreview(controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }

    func documentInteractionControllerDidEndPreview(controller: UIDocumentInteractionController) {
        do {
            try NSFileManager.defaultManager().removeItemAtPath(getTempDir())
        } catch {
            log.error("Could not delete temp directory.")
        }
    }

}
