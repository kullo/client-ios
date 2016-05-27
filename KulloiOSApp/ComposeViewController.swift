/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import LibKullo
import MobileCoreServices
import UIKit

class ComposeViewController: UIViewController, UITextViewDelegate {
    
    // MARK: properties
    
    var convId : Int64!
    private weak var alertDialog: UIAlertController?
    private var draftState: KADraftState?

    private let attachmentsSegueId = "ComposeEmbedAttachmentsSegue"
    private var attachmentsList: AttachmentsViewController?
    private var attachmentIds = [Int64]()
    private let viewName = "Compose"

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
                return draftState == .Editing &&
                    (!messageTextView.text.isEmpty || !attachmentIds.isEmpty)
            } else {
                return false
            }
        }
    }

    // MARK: lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        messageTextView.delegate = self
        messageTextView.becomeFirstResponder()
        scrollViewTapRecognizer.delegate = self
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardNotifcationListenerForScrollView(scrollView)
        KulloConnector.sharedInstance.addSessionEventsDelegate(self)

        reloadRecipientData()
        reloadDraft()
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)

        KulloConnector.sharedInstance.removeSessionEventsDelegate(self)
        removeKeyboardNotificationListeners()
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        super.prepareForSegue(segue, sender: sender)

        if segue.identifier == attachmentsSegueId {
            attachmentsList = (segue.destinationViewController as! AttachmentsViewController)
            attachmentsList?.dataSource = self
            attachmentsList?.delegate = self
            attachmentsList?.removable = true
            attachmentsList?.attachmentsAreDownloaded = true
            attachmentsList?.scrollable = false
        }
    }

    // MARK: text view delegate

    func textViewDidChange(textView: UITextView) {
        if let convId = convId {
            KulloConnector.sharedInstance.saveDraftForConversation(convId, message: messageTextView.text, prepareToSend: false)
            sendButton.enabled = readyToSend
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
            messageTextView.editable = draftState == .Editing
            sendButton.enabled = readyToSend
        }
    }

    func reloadDraftText() {
        if let convId = convId {
            messageTextView.text = KulloConnector.sharedInstance.getDraftText(convId)
            sendButton.enabled = readyToSend
        }
    }

    func reloadDraftAttachments() {
        attachmentIds = KulloConnector.sharedInstance.getDraftAttachmentIds(convId)
        sendButton.enabled = readyToSend
        if let attachmentsList = attachmentsList {
            attachmentsList.reloadData()
            attachmentsListHeight.constant = attachmentsList.contentHeight
        }
    }

    // MARK: actions

    @IBAction func scrollViewTapped(sender: UITapGestureRecognizer) {
        if sender.state == .Ended {
            messageTextView.becomeFirstResponder()
        }
    }

    @IBAction func addAttachmentsButtonTapped(sender: UIButton) {
        let imagePickerController = UIImagePickerController()
        imagePickerController.delegate = self
        imagePickerController.sourceType = .PhotoLibrary
        // If this list is extended, the switch in
        // imagePickerController:didFinishPickingMediaWithInfo:
        // must also be extended.
        imagePickerController.mediaTypes = [kUTTypeImage as String, kUTTypeMovie as String]

        presentViewController(imagePickerController, animated: true, completion: nil)
    }

    @IBAction func sendButtonClicked(sender: AnyObject) {
        if let convId = convId {
            alertDialog = showWaitingDialog(
                NSLocalizedString("Sending messages", comment: ""),
                message: NSLocalizedString("Please wait...", comment: "")
            )

            let text = messageTextView.text.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            KulloConnector.sharedInstance.saveDraftForConversation(convId, message: text, prepareToSend: true)
            KulloConnector.sharedInstance.addSyncDelegate(self)
            KulloConnector.sharedInstance.sync(.SendOnly)
        }
    }
    
}

extension ComposeViewController : UIGestureRecognizerDelegate {

    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        let location = touch.locationInView(scrolledContentView)
        return !scrolledContentView.pointInside(location, withEvent: nil)
    }

}

extension ComposeViewController : AttachmentsViewDataSource {

    func attachmentsViewNumberOfAttachments() -> Int {
        return attachmentIds.count
    }

    func attachmentsViewMetadataForAttachment(attachmentIndex: Int) -> AttachmentMeta {
        let attachmentId = attachmentIds[attachmentIndex]
        return AttachmentMeta(
            filename: KulloConnector.sharedInstance.getDraftAttachmentFilename(convId, attachmentId: attachmentId),
            size: KulloConnector.sharedInstance.getDraftAttachmentFilesize(convId, attachmentId: attachmentId)
        )
    }

    func attachmentsViewSaveAttachment(attachmentIndex: Int, path: String) {
        KulloConnector.sharedInstance.saveDraftAttachment(
            convId,
            attachmentId: attachmentIds[attachmentIndex],
            path: path,
            delegate: self
        )
    }

    func attachmentsViewRemoveAttachment(attachmentIndex: Int) {
        KulloConnector.sharedInstance.removeDraftAttachment(convId, attachmentId: attachmentIds[attachmentIndex])
        reloadDraftAttachments()
    }

}

extension ComposeViewController : AttachmentsViewDelegate {

    func attachmentsViewWillOpenAttachment(attachmentIndex: Int) {
        messageTextView.resignFirstResponder()
    }

}

extension ComposeViewController : DraftAttachmentsSaveToDelegate {

    func draftAttachmentsSaveToFinished(convId: Int64, attId: Int64, path: String) {
        attachmentsList?.saveToFinished(path)
    }

    func draftAttachmentsSaveToError(convId: Int64, attId: Int64, path: String, error: String) {
        attachmentsList?.saveToError(path, error: error)
    }

}

extension ComposeViewController : UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    private func dedupeFilename(convId: Int64, filename: String) -> String {
        let filenameNSString = NSString(string: filename)
        let filenameBasename = filenameNSString.stringByDeletingPathExtension
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
                    dupeCounter++
                    result = "\(filenameBasename)-\(dupeCounter).\(filenameExtension)"
                }
            }
        } while isDuplicate

        return result
    }

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        let mediaType = info[UIImagePickerControllerMediaType] as! NSString
        var path = ""
        var errorMsg: String?
        switch mediaType {

        case kUTTypeImage:
            let url = info[UIImagePickerControllerReferenceURL] as! NSURL
            let image = info[UIImagePickerControllerOriginalImage] as! UIImage

            var imageDataOpt: NSData?
            var imageExtension: String
            switch url.pathExtension!.lowercaseString {
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
            let filename = "\((url.lastPathComponent! as NSString).stringByDeletingPathExtension).\(imageExtension)"
            path = StorageManager.getTempPathForView(viewName, filename: dedupeFilename(convId, filename: filename))
            guard imageData.writeToFile(path, atomically: false) else {
                errorMsg = NSLocalizedString("Error while saving attachment", comment: "")
                break
            }

        case kUTTypeMovie:
            let originalUrl = info[UIImagePickerControllerMediaURL] as! NSURL
            let filename = originalUrl.lastPathComponent!
            path = StorageManager.getTempPathForView(viewName, filename: dedupeFilename(convId, filename: filename))
            do {
                try NSFileManager.defaultManager().moveItemAtPath(originalUrl.path!, toPath: path)
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
            picker.dismissViewControllerAnimated(true, completion: {
                let alert = UIAlertController(
                    title: NSLocalizedString("Error while adding attachment", comment: ""),
                    message: errorMsg,
                    preferredStyle: .Alert
                )
                alert.addAction(AlertHelper.getAlertOKAction())
                self.presentViewController(alert, animated: true, completion: nil)
            })

        } else {
            log.debug("attachment to be added: \(path)")
            KulloConnector.sharedInstance.addAttachmentToDraft(convId, path: path, delegate: self)
            picker.dismissViewControllerAnimated(true, completion: nil)
        }
    }

}

extension ComposeViewController : DraftAttachmentsAddDelegate {

    func deleteTemp() {
        do {
            try NSFileManager.defaultManager().removeItemAtPath(StorageManager.getTempPathForView(viewName))
        } catch {
            log.error("Could not delete temp directory.")
        }
    }

    func draftAttachmentsAddFinished(convId: Int64, attId: Int64, path: String) {
        deleteTemp()
        reloadDraftAttachments()
    }

    func draftAttachmentsAddError(convId: Int64, path: String, error: String) {
        deleteTemp()
        showInfoDialog(NSLocalizedString("Error while adding attachment", comment: ""), message: "")
    }

}

extension ComposeViewController : SyncDelegate {

    func syncStarted() {
        // do nothing
    }

    func syncProgressed() {
        // do nothing
    }

    func syncDraftAttachmentsTooBig(convId: Int64) {
        if let alertDialog = alertDialog {
            alertDialog.title = NSLocalizedString("Attachments too big", comment: "")
            alertDialog.message = NSLocalizedString("The attachments of the message you were trying to send were too big.", comment: "")
            alertDialog.addAction(AlertHelper.getAlertOKAction())
        }
        log.info("Attachments too big for \(convId)")
        KulloConnector.sharedInstance.removeSyncDelegate(self)
    }
    
    func syncFinished() {
        alertDialog?.dismissViewControllerAnimated(true, completion: { () -> Void in
            self.navigationController!.popViewControllerAnimated(true)
        })
        KulloConnector.sharedInstance.removeSyncDelegate(self)
    }
    
    func syncError(error: String) {
        if let alertDialog = alertDialog {
            alertDialog.title = NSLocalizedString("Synchronization error", comment: "")
            alertDialog.message = error
            alertDialog.addAction(AlertHelper.getAlertOKAction())
        }
        log.info("Sync error \(error)")
        KulloConnector.sharedInstance.removeSyncDelegate(self)
    }
}

extension ComposeViewController : SessionEventsDelegate {
    
    func sessionEventDraftStateChanged(convId: Int64) {
        if convId == self.convId {
            reloadDraftState()
        }
    }
    
    func sessionEventDraftTextChanged(convId: Int64) {
        if convId == self.convId {
            reloadDraftText()
        }
    }
    
    func sessionEventDraftAttachmentAdded(convId: Int64) {
        if convId == self.convId {
            reloadDraftAttachments()
        }
    }
    
    func sessionEventDraftAttachmentRemoved(convId: Int64) {
        if convId == self.convId {
            reloadDraftAttachments()
        }
    }
}
