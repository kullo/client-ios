/* Copyright 2015 Kullo GmbH. All rights reserved. */

import UIKit
import LibKullo

class ComposeViewController: UIViewController, UITextViewDelegate {
    
    // MARK: properties
    
    var convId : Int64?
    private weak var alertDialog: UIAlertController?
    private var draftState: KADraftState?
    
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var messageTextView: UITextView!
    @IBOutlet var conversationTitleLabel: UILabel!
    @IBOutlet var conversationImageView: UIImageView!
    @IBOutlet var messageMinHeightConstraint: NSLayoutConstraint!
    @IBOutlet var sendButton: UIBarButtonItem!

    var readyToSend: Bool {
        get {
            if let draftState = draftState {
                return draftState == .Editing && !messageTextView.text.isEmpty
            } else {
                return false
            }
        }
    }

    // MARK: lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        messageTextView.delegate = self
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        setupKeyboardNotifcationListenerForScrollView(scrollView)
        KulloConnector.sharedInstance.addSessionEventsDelegate(self)

        reloadRecipientData()
        reloadDraft()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        let distanceBetweenScrollViewTopAndMessageTextViewTop = scrollView.convertPoint(
            messageTextView.frame.origin, fromView: messageTextView.superview).y

        messageMinHeightConstraint.constant =
            scrollView.frame.height - distanceBetweenScrollViewTopAndMessageTextViewTop
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)

        KulloConnector.sharedInstance.removeSessionEventsDelegate(self)
        removeKeyboardNotificationListeners()
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

    // MARK: actions
    
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

extension ComposeViewController : SyncDelegate {
    
    func syncErrorDraftAttachmentsTooBig(convId: Int64) {
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
        if convId == self.convId! {
            reloadDraftState()
        }
    }
    
    func sessionEventDraftTextChanged(convId: Int64) {
        if convId == self.convId! {
            reloadDraftText()
        }
    }
    
    func sessionEventDraftAttachmentAdded(convId: Int64) {
        
    }
    
    func sessionEventDraftAttachmentRemoved(convId: Int64) {
        
    }
}
