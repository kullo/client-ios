/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import CoreGraphics
import UIKit
import XCGLogger

class MessageAttachmentsViewController: UIViewController {

    @IBOutlet var downloadBarButtonItem: UIBarButtonItem!

    var messageId: Int64!

    fileprivate let attachmentsSegueId = "MessageEmbedAttachmentsSegue"
    fileprivate var attachmentsList: AttachmentsViewController?
    fileprivate var attachmentIds = [Int64]()

    fileprivate weak var alertDialog: UIAlertController?

    // MARK: lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateDataAndRefreshUI()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if segue.identifier == attachmentsSegueId {
            attachmentsList = (segue.destination as! AttachmentsViewController)
            attachmentsList?.dataSource = self
        }
    }

    // MARK: actions

    @IBAction func dismiss() {
        navigationController!.dismiss(animated: true, completion: nil)
    }

    // MARK: download

    @IBAction func download() {
        alertDialog = showWaitingDialog(
            NSLocalizedString("Downloading attachments", comment: ""),
            message: downloadingAlertMessage()
        )

        KulloConnector.sharedInstance.addSyncDelegate(self)
        KulloConnector.sharedInstance.downloadAttachments(messageId)
    }

    fileprivate func downloadingAlertMessage() -> String {
        let message = NSLocalizedString("Please wait...", comment: "")
        let progress = KulloConnector.sharedInstance.getAttachmentDownloadProgress()
        return "\(message) \(Int(round(progress * 100)))%"
    }

    // MARK: Data

    func updateDataAndRefreshUI() {
        if let messageId = messageId {
            attachmentsList?.attachmentsAreDownloaded = KulloConnector.sharedInstance.getMessageAttachmentsDownloaded(messageId)
            attachmentIds = KulloConnector.sharedInstance.getMessageAttachmentIds(messageId)

            if attachmentsList?.attachmentsAreDownloaded ?? false {
                downloadBarButtonItem.isEnabled = false
                downloadBarButtonItem.tintColor = UIColor.clear
            }
            attachmentsList?.reloadData()
        }
    }

}

extension MessageAttachmentsViewController: MessageAttachmentsSaveToDelegate {

    func messageAttachmentsSaveToFinished(_ msgId: Int64, attId: Int64, path: String) {
        attachmentsList?.saveToFinished(path)
    }

    func messageAttachmentsSaveToError(_ msgId: Int64, attId: Int64, path: String, error: String) {
        attachmentsList?.saveToError(path, error: error)
    }

}

extension MessageAttachmentsViewController: AttachmentsViewDataSource {

    func attachmentsViewNumberOfAttachments() -> Int {
        return attachmentIds.count
    }

    func attachmentsViewMetadataForAttachment(_ attachmentIndex: Int) -> AttachmentMeta {
        let attachmentId = attachmentIds[attachmentIndex]
        return AttachmentMeta(
            filename: KulloConnector.sharedInstance.getMessageAttachmentFilename(messageId, attachmentId: attachmentId),
            size: KulloConnector.sharedInstance.getMessageAttachmentFilesize(messageId, attachmentId: attachmentId)
        )
    }

    func attachmentsViewSaveAttachment(_ attachmentIndex: Int, path: String) {
        KulloConnector.sharedInstance.saveMessageAttachment(
            messageId,
            attachmentId: attachmentIds[attachmentIndex],
            path: path,
            delegate: self
        )
    }

    func attachmentsViewRemoveAttachment(_ attachmentIndex: Int) {
        preconditionFailure("Message attachments cannot be removed")
    }

}

extension MessageAttachmentsViewController: SyncDelegate {

    // MARK: sync delegate

    func syncStarted() {
        // do nothing
    }

    func syncProgressed() {
        guard let alertDialog = alertDialog else { return }

        alertDialog.message = downloadingAlertMessage()
    }

    func syncDraftAttachmentsTooBig(_ convId: Int64) {
        if let alertDialog = alertDialog {
            alertDialog.title = NSLocalizedString("Attachments too big", comment: "")
            alertDialog.message = NSLocalizedString("Attachments at one conversation are too big.", comment: "")
            alertDialog.addAction(AlertHelper.getAlertOKAction())
        }
        KulloConnector.sharedInstance.removeSyncDelegate(self)
    }

    func syncFinished() {
        log.info("Sync finished successfully, attachments are downloaded.")
        alertDialog?.dismiss(animated: true, completion: { () -> Void in
            self.updateDataAndRefreshUI()
        })
        KulloConnector.sharedInstance.removeSyncDelegate(self)
    }

    func syncError(_ error: String) {
        if let alertDialog = alertDialog {
            alertDialog.title = NSLocalizedString("Synchronization error", comment: "")
            alertDialog.message = error
            alertDialog.addAction(AlertHelper.getAlertOKAction())
        }
        KulloConnector.sharedInstance.removeSyncDelegate(self)
    }

}
