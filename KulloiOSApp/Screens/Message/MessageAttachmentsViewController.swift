/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import CoreGraphics
import UIKit

class MessageAttachmentsViewController: UIViewController {

    private var downloadButton: UIBarButtonItem!

    var messageId: Int64!

    private let attachmentsList = AttachmentsViewController()
    private var attachmentIds = [Int64]()

    private weak var alertDialog: UIAlertController?

    // MARK: lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Attachments", comment: "")

        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .stop, target: self, action: #selector(closeTapped))
        navigationItem.leftBarButtonItem = closeButton

        downloadButton = UIBarButtonItem(
            title: NSLocalizedString("Download", comment: ""), style: .plain,
            target: self, action: #selector(downloadTapped))
        navigationItem.rightBarButtonItem = downloadButton

        attachmentsList.dataSource = self
        addChildViewController(attachmentsList)
        view.addSubview(attachmentsList.view)
        attachmentsList.didMove(toParentViewController: self)
        attachmentsList.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateDataAndRefreshUI()
    }

    // MARK: actions

    @objc private func closeTapped() {
        navigationController?.dismiss(animated: true, completion: nil)
    }

    // MARK: download

    @objc private func downloadTapped() {
        alertDialog = showWaitingDialog(
            NSLocalizedString("Downloading attachments", comment: ""),
            message: downloadingAlertMessage()
        )

        KulloConnector.shared.addSyncDelegate(self)
        KulloConnector.shared.downloadAttachments(messageId)
    }

    private func downloadingAlertMessage() -> String {
        let message = NSLocalizedString("Please wait...", comment: "")
        let progress = KulloConnector.shared.getAttachmentDownloadProgress()
        return "\(message) \(Int(round(progress * 100)))%"
    }

    // MARK: Data

    func updateDataAndRefreshUI() {
        if let messageId = messageId {
            attachmentsList.attachmentsAreDownloaded = KulloConnector.shared.getMessageAttachmentsDownloaded(messageId)
            attachmentIds = KulloConnector.shared.getMessageAttachmentIds(messageId)

            if attachmentsList.attachmentsAreDownloaded {
                downloadButton.isEnabled = false
                downloadButton.tintColor = UIColor.clear
            }
            attachmentsList.reloadData()
        }
    }

}

extension MessageAttachmentsViewController: MessageAttachmentsSaveToDelegate {

    func messageAttachmentsSaveToFinished(_ msgId: Int64, attId: Int64, path: String) {
        attachmentsList.saveToFinished(path)
    }

    func messageAttachmentsSaveToError(_ msgId: Int64, attId: Int64, path: String, error: String) {
        attachmentsList.saveToError(path, error: error)
    }

}

extension MessageAttachmentsViewController: AttachmentsViewDataSource {

    func attachmentsViewNumberOfAttachments() -> Int {
        return attachmentIds.count
    }

    func attachmentsViewMetadataForAttachment(_ attachmentIndex: Int) -> AttachmentMeta {
        let attachmentId = attachmentIds[attachmentIndex]
        return AttachmentMeta(
            filename: KulloConnector.shared.getMessageAttachmentFilename(messageId, attachmentId: attachmentId),
            size: KulloConnector.shared.getMessageAttachmentFilesize(messageId, attachmentId: attachmentId)
        )
    }

    func attachmentsViewSaveAttachment(_ attachmentIndex: Int, path: String) {
        KulloConnector.shared.saveMessageAttachment(
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
        KulloConnector.shared.removeSyncDelegate(self)
    }

    func syncFinished() {
        log.info("Sync finished successfully, attachments are downloaded.")
        alertDialog?.dismiss(animated: true, completion: { () -> Void in
            self.updateDataAndRefreshUI()
        })
        KulloConnector.shared.removeSyncDelegate(self)
    }

    func syncError(_ error: String) {
        if let alertDialog = alertDialog {
            alertDialog.title = NSLocalizedString("Synchronization error", comment: "")
            alertDialog.message = error
            alertDialog.addAction(AlertHelper.getAlertOKAction())
        }
        KulloConnector.shared.removeSyncDelegate(self)
    }

}
