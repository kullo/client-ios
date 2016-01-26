/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import CoreGraphics
import UIKit
import XCGLogger

class MessageAttachmentsViewController: UIViewController {

    @IBOutlet var downloadBarButtonItem: UIBarButtonItem!

    var messageId: Int64!

    private let attachmentsSegueId = "MessageEmbedAttachmentsSegue"
    private var attachmentsList: AttachmentsViewController?
    private var attachmentIds = [Int64]()

    private weak var alertDialog: UIAlertController?

    // MARK: lifecycle

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        updateDataAndRefreshUI()
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        super.prepareForSegue(segue, sender: sender)

        if segue.identifier == attachmentsSegueId {
            attachmentsList = (segue.destinationViewController as! AttachmentsViewController)
            attachmentsList?.dataSource = self
        }
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
        KulloConnector.sharedInstance.downloadAttachments(messageId)
    }

    // MARK: Data

    func updateDataAndRefreshUI() {
        if let messageId = messageId {
            attachmentsList?.attachmentsAreDownloaded = KulloConnector.sharedInstance.getMessageAttachmentsDownloaded(messageId)
            attachmentIds = KulloConnector.sharedInstance.getMessageAttachmentIds(messageId)

            if attachmentsList?.attachmentsAreDownloaded ?? false {
                downloadBarButtonItem.enabled = false
                downloadBarButtonItem.tintColor = UIColor.clearColor()
            }
            attachmentsList?.reloadData()
        }
    }

}

extension MessageAttachmentsViewController : MessageAttachmentsSaveToDelegate {

    func messageAttachmentsSaveToFinished(msgId: Int64, attId: Int64, path: String) {
        attachmentsList?.saveToFinished(path)
    }

    func messageAttachmentsSaveToError(msgId: Int64, attId: Int64, path: String, error: String) {
        attachmentsList?.saveToError(path, error: error)
    }

}

extension MessageAttachmentsViewController : AttachmentsViewDataSource {

    func attachmentsViewNumberOfAttachments() -> Int {
        return attachmentIds.count
    }

    func attachmentsViewMetadataForAttachment(attachmentIndex: Int) -> AttachmentMeta {
        let attachmentId = attachmentIds[attachmentIndex]
        return AttachmentMeta(
            filename: KulloConnector.sharedInstance.getMessageAttachmentFilename(messageId, attachmentId: attachmentId),
            size: KulloConnector.sharedInstance.getMessageAttachmentFilesize(messageId, attachmentId: attachmentId)
        )
    }

    func attachmentsViewSaveAttachment(attachmentIndex: Int, path: String) {
        KulloConnector.sharedInstance.saveMessageAttachment(
            messageId,
            attachmentId: attachmentIds[attachmentIndex],
            path: path,
            delegate: self
        )
    }

    func attachmentsViewRemoveAttachment(attachmentIndex: Int) {
        preconditionFailure("Message attachments cannot be removed")
    }

}

extension MessageAttachmentsViewController : SyncDelegate {

    // MARK: sync delegate

    func syncStarted() {
        // do nothing
    }

    func syncProgressed() {
        // do nothing

    }

    func syncDraftAttachmentsTooBig(convId: Int64) {
        if let alertDialog = alertDialog {
            alertDialog.title = NSLocalizedString("Attachments too big", comment: "")
            alertDialog.message = NSLocalizedString("Attachments at one conversation are too big.", comment: "")
            alertDialog.addAction(AlertHelper.getAlertOKAction())
        }
        KulloConnector.sharedInstance.removeSyncDelegate(self)
    }

    func syncFinished() {
        log.info("Sync finished successfully, attachments are downloaded.")
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
