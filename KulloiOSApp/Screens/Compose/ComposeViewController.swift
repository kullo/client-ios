/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import LibKullo
import MobileCoreServices
import UIKit

class ComposeViewController: UIViewController, UITextViewDelegate {
    
    // MARK: properties
    
    var convId: Int64!
    fileprivate weak var alertDialog: UIAlertController?
    fileprivate var draftState: KADraftState?

    fileprivate let attachmentsSegueId = "ComposeEmbedAttachmentsSegue"
    fileprivate var attachmentsList: AttachmentsViewController?
    fileprivate var attachmentIds = [Int64]()
    fileprivate let viewName = "Compose"

    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var scrolledContentView: UIView!
    @IBOutlet var scrollViewTapRecognizer: UITapGestureRecognizer!
    @IBOutlet var messageTextView: UITextView!
    @IBOutlet var attachmentsListHeight: NSLayoutConstraint!
    @IBOutlet var conversationTitleLabel: UILabel!
    @IBOutlet var conversationImageView: UIImageView!
    @IBOutlet var sendButton: UIBarButtonItem!

    var readyToSend: Bool {
        get {
            if let draftState = draftState {
                return draftState == .editing &&
                    (!messageTextView.text.isEmpty || !attachmentIds.isEmpty)
            } else {
                return false
            }
        }
    }

    // MARK: lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // let conversationImageView calculate its size
        conversationImageView.layoutIfNeeded()

        messageTextView.delegate = self
        scrollViewTapRecognizer.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardNotifcationListenerForScrollView(scrollView)
        KulloConnector.sharedInstance.addSessionEventsDelegate(self)

        reloadRecipientData()
        reloadDraft()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        messageTextView.becomeFirstResponder()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        KulloConnector.sharedInstance.removeSessionEventsDelegate(self)
        removeKeyboardNotificationListeners()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if segue.identifier == attachmentsSegueId {
            attachmentsList = (segue.destination as! AttachmentsViewController)
            attachmentsList?.dataSource = self
            attachmentsList?.delegate = self
            attachmentsList?.removable = true
            attachmentsList?.attachmentsAreDownloaded = true
            attachmentsList?.scrollable = false
        }
    }

    // MARK: text view delegate

    func textViewDidChange(_ textView: UITextView) {
        if let convId = convId {
            KulloConnector.sharedInstance.saveDraftForConversation(convId, message: messageTextView.text, prepareToSend: false)
            sendButton.isEnabled = readyToSend
        }
    }
    
    // MARK: update content

    func reloadRecipientData() {
        if let convId = convId {
            let conversationName = KulloConnector.sharedInstance.getConversationNameOrPlaceHolder(convId)
            let conversationImage = KulloConnector.sharedInstance.getConversationImage(convId, size: conversationImageView.frame.size)
            conversationTitleLabel.text = conversationName
            conversationImageView.image = conversationImage
            conversationImageView.showAsCircle()
        }
    }

    func reloadDraft() {
        reloadDraftState()
        reloadDraftText()
        reloadDraftAttachments()
    }

    func reloadDraftState() {
        if let convId = convId {
            let draftState = KulloConnector.sharedInstance.getDraftState(convId)
            self.draftState = draftState
            messageTextView.isEditable = draftState == .editing
            sendButton.isEnabled = readyToSend
        }
    }

    func reloadDraftText() {
        if let convId = convId {
            messageTextView.text = KulloConnector.sharedInstance.getDraftText(convId)
            sendButton.isEnabled = readyToSend
        }
    }

    func reloadDraftAttachments() {
        attachmentIds = KulloConnector.sharedInstance.getDraftAttachmentIds(convId)
        sendButton.isEnabled = readyToSend
        if let attachmentsList = attachmentsList {
            attachmentsList.reloadData()
            attachmentsListHeight.constant = attachmentsList.contentHeight
        }
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

    @IBAction func sendButtonClicked(_ sender: AnyObject) {
        if let convId = convId {
            alertDialog = showWaitingDialog(
                NSLocalizedString("Sending messages", comment: ""),
                message: syncingAlertMessage()
            )

            let text = messageTextView.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            KulloConnector.sharedInstance.saveDraftForConversation(convId, message: text, prepareToSend: true)
            KulloConnector.sharedInstance.addSyncDelegate(self)
            KulloConnector.sharedInstance.sync(.sendOnly)
        }
    }

    fileprivate func syncingAlertMessage() -> String {
        let message = NSLocalizedString("Please wait...", comment: "")
        let progress = KulloConnector.sharedInstance.getSendingProgress()
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
            filename: KulloConnector.sharedInstance.getDraftAttachmentFilename(convId, attachmentId: attachmentId),
            size: KulloConnector.sharedInstance.getDraftAttachmentFilesize(convId, attachmentId: attachmentId)
        )
    }

    func attachmentsViewSaveAttachment(_ attachmentIndex: Int, path: String) {
        KulloConnector.sharedInstance.saveDraftAttachment(
            convId,
            attachmentId: attachmentIds[attachmentIndex],
            path: path,
            delegate: self
        )
    }

    func attachmentsViewRemoveAttachment(_ attachmentIndex: Int) {
        KulloConnector.sharedInstance.removeDraftAttachment(convId, attachmentId: attachmentIds[attachmentIndex])
        reloadDraftAttachments()
    }

}

extension ComposeViewController: AttachmentsViewDelegate {

    func attachmentsViewWillOpenAttachment(_ attachmentIndex: Int) {
        messageTextView.resignFirstResponder()
    }

}

extension ComposeViewController: DraftAttachmentsSaveToDelegate {

    func draftAttachmentsSaveToFinished(_ convId: Int64, attId: Int64, path: String) {
        attachmentsList?.saveToFinished(path)
    }

    func draftAttachmentsSaveToError(_ convId: Int64, attId: Int64, path: String, error: String) {
        attachmentsList?.saveToError(path, error: error)
    }

}

extension ComposeViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    fileprivate func dedupeFilename(_ convId: Int64, filename: String) -> String {
        let filenameNSString = NSString(string: filename)
        let filenameBasename = filenameNSString.deletingPathExtension
        let filenameExtension = filenameNSString.pathExtension

        let otherFilenames = KulloConnector.sharedInstance.getDraftAttachmentFilenames(convId)
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
        let mediaType = info[UIImagePickerControllerMediaType] as! NSString
        var path = ""
        var errorMsg: String?
        switch mediaType {

        case kUTTypeImage:
            let url = info[UIImagePickerControllerReferenceURL] as! URL
            let image = info[UIImagePickerControllerOriginalImage] as! UIImage

            var imageDataOpt: Data?
            var imageExtension: String
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
            let filename = "\((url.lastPathComponent as NSString).deletingPathExtension).\(imageExtension)"
            path = StorageManager.getTempPathForView(viewName, filename: dedupeFilename(convId, filename: filename))
            guard (try? imageData.write(to: URL(fileURLWithPath: path), options: [])) != nil else {
                errorMsg = NSLocalizedString("Error while saving attachment", comment: "")
                break
            }

        case kUTTypeMovie:
            let originalUrl = info[UIImagePickerControllerMediaURL] as! URL
            let filename = originalUrl.lastPathComponent
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
            KulloConnector.sharedInstance.addAttachmentToDraft(convId, path: path, delegate: self)
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
        KulloConnector.sharedInstance.removeSyncDelegate(self)
    }
    
    func syncFinished() {
        alertDialog?.dismiss(animated: true, completion: { () -> Void in
            self.navigationController!.popViewController(animated: true)
        })
        KulloConnector.sharedInstance.removeSyncDelegate(self)
    }
    
    func syncError(_ error: String) {
        if let alertDialog = alertDialog {
            alertDialog.title = NSLocalizedString("Synchronization error", comment: "")
            alertDialog.message = error
            alertDialog.addAction(AlertHelper.getAlertOKAction())
        }
        log.info("Sync error \(error)")
        KulloConnector.sharedInstance.removeSyncDelegate(self)
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
