/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import LibKullo
import MobileCoreServices
import UIKit

class ComposeViewController: UIViewController, UITextViewDelegate {
    
    // MARK: properties
    
    var convId: Int64!
    private weak var alertDialog: UIAlertController?
    private var draftState: KADraftState?

    private let attachmentsList = AttachmentsViewController()
    private var attachmentIds = [Int64]()
    private let viewName = "Compose"

    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var scrolledContentView: UIView!
    @IBOutlet var scrollViewTapRecognizer: UITapGestureRecognizer!
    @IBOutlet var messageTextView: UITextView!
    @IBOutlet var attachmentsContainer: UIView!
    @IBOutlet var attachmentsListHeight: NSLayoutConstraint!
    @IBOutlet var conversationTitleLabel: UILabel!
    @IBOutlet var conversationImageView: UIImageView!
    private var sendButton: UIBarButtonItem!

    private var readyToSend: Bool {
        if let draftState = draftState {
            return draftState == .editing &&
                (!messageTextView.text.isEmpty || !attachmentIds.isEmpty)
        } else {
            return false
        }
    }

    // MARK: lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // let conversationImageView calculate its size
        conversationImageView.layoutIfNeeded()

        sendButton = UIBarButtonItem(
            title: NSLocalizedString("Send", comment: ""), style: .plain,
            target: self, action: #selector(sendTapped))
        navigationItem.rightBarButtonItem = sendButton

        attachmentsList.dataSource = self
        attachmentsList.delegate = self
        attachmentsList.removable = true
        attachmentsList.attachmentsAreDownloaded = true
        attachmentsList.scrollable = false

        addChildViewController(attachmentsList)
        attachmentsContainer.addSubview(attachmentsList.view)
        attachmentsList.didMove(toParentViewController: self)

        attachmentsList.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            NSLayoutConstraint(
                item: attachmentsList.view, attribute: .leading, relatedBy: .equal,
                toItem: attachmentsContainer, attribute: .leading, multiplier: 1, constant: 0),
            NSLayoutConstraint(
                item: attachmentsList.view, attribute: .trailing, relatedBy: .equal,
                toItem: attachmentsContainer, attribute: .trailing, multiplier: 1, constant: 0),
            NSLayoutConstraint(
                item: attachmentsList.view, attribute: .top, relatedBy: .equal,
                toItem: attachmentsContainer, attribute: .top, multiplier: 1, constant: 0),
            NSLayoutConstraint(
                item: attachmentsList.view, attribute: .bottom, relatedBy: .equal,
                toItem: attachmentsContainer, attribute: .bottom, multiplier: 1, constant: 0),
        ])

        messageTextView.delegate = self
        scrollViewTapRecognizer.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardNotifcationListenerForScrollView(scrollView)
        KulloConnector.shared.addSessionEventsDelegate(self)

        reloadRecipientData()
        reloadDraft()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        messageTextView.becomeFirstResponder()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        KulloConnector.shared.removeSessionEventsDelegate(self)
        removeKeyboardNotificationListeners()
    }

    // MARK: text view delegate

    func textViewDidChange(_ textView: UITextView) {
        if let convId = convId {
            KulloConnector.shared.saveDraftForConversation(convId, message: messageTextView.text, prepareToSend: false)
            sendButton.isEnabled = readyToSend
        }
    }
    
    // MARK: update content

    private func reloadRecipientData() {
        if let convId = convId {
            let conversationName = KulloConnector.shared.getConversationNameOrPlaceHolder(convId)
            let conversationImage = KulloConnector.shared.getConversationImage(convId, size: conversationImageView.frame.size)
            conversationTitleLabel.text = conversationName
            conversationImageView.image = conversationImage
            conversationImageView.showAsCircle()
        }
    }

    private func reloadDraft() {
        reloadDraftState()
        reloadDraftText()
        reloadDraftAttachments()
    }

    private func reloadDraftState() {
        if let convId = convId {
            let draftState = KulloConnector.shared.getDraftState(convId)
            self.draftState = draftState
            messageTextView.isEditable = draftState == .editing
            sendButton.isEnabled = readyToSend
        }
    }

    private func reloadDraftText() {
        if let convId = convId {
            let newDraftText = KulloConnector.shared.getDraftText(convId)
            if newDraftText != messageTextView.text {
                messageTextView.text = newDraftText
            }
            sendButton.isEnabled = readyToSend
        }
    }

    private func reloadDraftAttachments() {
        attachmentIds = KulloConnector.shared.getDraftAttachmentIds(convId)
        sendButton.isEnabled = readyToSend
        attachmentsList.reloadData()
    }

    // MARK: actions

    @IBAction func scrollViewTapped(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            messageTextView.becomeFirstResponder()
        }
    }

    @IBAction func addAttachmentsButtonTapped(_ sender: UIButton) {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .photoLibrary
        // If this list is extended, the switch in
        // imagePickerController:didFinishPickingMediaWithInfo:
        // must also be extended.
        imagePickerController.mediaTypes = [kUTTypeImage as String, kUTTypeMovie as String]

        present(imagePickerController, animated: true, completion: nil)
    }

    @objc private func sendTapped() {
        if let convId = convId {
            alertDialog = showWaitingDialog(
                NSLocalizedString("Sending messages", comment: ""),
                message: syncingAlertMessage()
            )

            let text = messageTextView.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            KulloConnector.shared.saveDraftForConversation(convId, message: text, prepareToSend: true)
            KulloConnector.shared.addSyncDelegate(self)
            KulloConnector.shared.sync(.sendOnly)
        }
    }

    private func syncingAlertMessage() -> String {
        let message = NSLocalizedString("Please wait...", comment: "")
        let progress = KulloConnector.shared.getSendingProgress()
        return "\(message) \(Int(round(progress * 100)))%"
    }
}

extension ComposeViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: scrolledContentView)
        return !scrolledContentView.point(inside: location, with: nil)
    }

}

extension ComposeViewController: AttachmentsViewDataSource {

    func attachmentsViewNumberOfAttachments() -> Int {
        return attachmentIds.count
    }

    func attachmentsViewMetadataForAttachment(_ attachmentIndex: Int) -> AttachmentMeta {
        let attachmentId = attachmentIds[attachmentIndex]
        return AttachmentMeta(
            filename: KulloConnector.shared.getDraftAttachmentFilename(convId, attachmentId: attachmentId),
            size: KulloConnector.shared.getDraftAttachmentFilesize(convId, attachmentId: attachmentId)
        )
    }

    func attachmentsViewSaveAttachment(_ attachmentIndex: Int, path: String) {
        KulloConnector.shared.saveDraftAttachment(
            convId,
            attachmentId: attachmentIds[attachmentIndex],
            path: path,
            delegate: self
        )
    }

    func attachmentsViewRemoveAttachment(_ attachmentIndex: Int) {
        KulloConnector.shared.removeDraftAttachment(convId, attachmentId: attachmentIds[attachmentIndex])
        reloadDraftAttachments()
    }

}

extension ComposeViewController: AttachmentsViewDelegate {
    func attachmentsViewLaidOut(contentHeight: CGFloat) {
        attachmentsListHeight.constant = contentHeight
    }

    func attachmentsViewWillOpenAttachment(_ attachmentIndex: Int) {
        messageTextView.resignFirstResponder()
    }
}

extension ComposeViewController: DraftAttachmentsSaveToDelegate {

    func draftAttachmentsSaveToFinished(_ convId: Int64, attId: Int64, path: String) {
        attachmentsList.saveToFinished(path)
    }

    func draftAttachmentsSaveToError(_ convId: Int64, attId: Int64, path: String, error: String) {
        attachmentsList.saveToError(path, error: error)
    }

}

extension ComposeViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    private func dedupeFilename(_ convId: Int64, filename: String) -> String {
        let filenameNSString = NSString(string: filename)
        let filenameBasename = filenameNSString.deletingPathExtension
        let filenameExtension = filenameNSString.pathExtension

        let otherFilenames = KulloConnector.shared.getDraftAttachmentFilenames(convId)
        var result = filename

        var isDuplicate: Bool
        var dupeCounter = 0
        repeat {
            isDuplicate = false
            for other in otherFilenames {
                if other == result {
                    isDuplicate = true
                    dupeCounter += 1
                    result = "\(filenameBasename)-\(dupeCounter).\(filenameExtension)"
                }
            }
        } while isDuplicate

        return result
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
        let mediaType = info[UIImagePickerControllerMediaType] as! String
        var path = ""
        var errorMsg: String?

        switch mediaType {
        case String(kUTTypeImage):
            let url = info[UIImagePickerControllerReferenceURL] as! URL
            let image = info[UIImagePickerControllerOriginalImage] as! UIImage

            // The URL always contains the file basename "asset", which isn't user friendly.
            let basename = NSLocalizedString("image_basename", comment: "")

            let imageDataOpt: Data?
            let imageExtension: String
            switch url.pathExtension.lowercased() {
            case "png":
                imageDataOpt = UIImagePNGRepresentation(image)
                imageExtension = "png"
            default:
                imageDataOpt = UIImageJPEGRepresentation(image, attachmentImageQuality)
                imageExtension = "jpg"
            }
            guard let imageData = imageDataOpt else {
                errorMsg = NSLocalizedString("Error while compressing picture", comment: "")
                break
            }
            let filename = "\(basename).\(imageExtension)"
            path = StorageManager.getTempPathForView(viewName, filename: dedupeFilename(convId, filename: filename))
            guard (try? imageData.write(to: URL(fileURLWithPath: path), options: [])) != nil else {
                errorMsg = NSLocalizedString("Error while saving attachment", comment: "")
                break
            }

        case String(kUTTypeMovie):
            let originalUrl = info[UIImagePickerControllerMediaURL] as! URL

            // The URL contains a UUID as the file's basename, which isn't user friendly.
            let basename = NSLocalizedString("video_basename", comment: "")

            let movieExtension = originalUrl.lastPathComponent.split(separator: ".").last!
            let filename = "\(basename).\(movieExtension)"
            path = StorageManager.getTempPathForView(viewName, filename: dedupeFilename(convId, filename: filename))
            do {
                try FileManager.default.moveItem(atPath: originalUrl.path, toPath: path)
            } catch {
                errorMsg = NSLocalizedString("Error while saving attachment", comment: "")
                break
            }

        default:
            log.error("Unhandled UTType: \(mediaType)")
            errorMsg = NSLocalizedString("Unknown media type", comment: "")
            break
        }

        if let errorMsg = errorMsg {
            picker.dismiss(animated: true, completion: {
                let alert = UIAlertController(
                    title: NSLocalizedString("Error while adding attachment", comment: ""),
                    message: errorMsg,
                    preferredStyle: .alert
                )
                alert.addAction(AlertHelper.getAlertOKAction())
                self.present(alert, animated: true, completion: nil)
            })

        } else {
            log.debug("attachment to be added: \(path)")
            KulloConnector.shared.addAttachmentToDraft(convId, path: path, delegate: self)
            picker.dismiss(animated: true, completion: nil)
        }
    }

}

extension ComposeViewController: DraftAttachmentsAddDelegate {

    func deleteTemp() {
        do {
            try FileManager.default.removeItem(atPath: StorageManager.getTempPathForView(viewName))
        } catch {
            log.error("Could not delete temp directory.")
        }
    }

    func draftAttachmentsAddFinished(_ convId: Int64, attId: Int64, path: String) {
        deleteTemp()
        reloadDraftAttachments()
    }

    func draftAttachmentsAddError(_ convId: Int64, path: String, error: String) {
        deleteTemp()
        showInfoDialog(NSLocalizedString("Error while adding attachment", comment: ""), message: error)
    }

}

extension ComposeViewController: SyncDelegate {

    func syncStarted() {
        // do nothing
    }

    func syncProgressed() {
        guard let alertDialog = alertDialog else { return }

        alertDialog.message = syncingAlertMessage()
    }

    func syncDraftAttachmentsTooBig(_ convId: Int64) {
        if let alertDialog = alertDialog {
            alertDialog.title = NSLocalizedString("Attachments too big", comment: "")
            alertDialog.message = NSLocalizedString("The attachments of the message you were trying to send were too big.", comment: "")
            alertDialog.addAction(AlertHelper.getAlertOKAction())
        }
        log.info("Attachments too big for \(convId)")
        KulloConnector.shared.removeSyncDelegate(self)
    }
    
    func syncFinished() {
        alertDialog?.dismiss(animated: true, completion: { () -> Void in
            self.navigationController!.popViewController(animated: true)
        })
        KulloConnector.shared.removeSyncDelegate(self)
    }
    
    func syncError(_ error: String) {
        if let alertDialog = alertDialog {
            alertDialog.title = NSLocalizedString("Synchronization error", comment: "")
            alertDialog.message = error
            alertDialog.addAction(AlertHelper.getAlertOKAction())
        }
        log.info("Sync error \(error)")
        KulloConnector.shared.removeSyncDelegate(self)
    }
}

extension ComposeViewController: SessionEventsDelegate {
    
    func sessionEventDraftStateChanged(_ convId: Int64) {
        if convId == self.convId {
            reloadDraftState()
        }
    }
    
    func sessionEventDraftTextChanged(_ convId: Int64) {
        if convId == self.convId {
            reloadDraftText()
        }
    }
    
    func sessionEventDraftAttachmentAdded(_ convId: Int64) {
        if convId == self.convId {
            reloadDraftAttachments()
        }
    }
    
    func sessionEventDraftAttachmentRemoved(_ convId: Int64) {
        if convId == self.convId {
            reloadDraftAttachments()
        }
    }
}
