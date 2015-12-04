/* Copyright 2015 Kullo GmbH. All rights reserved. */

import UIKit
import XCGLogger

class MessageViewController: UIViewController {

    // MARK: Properties

    let composeMessageSegueIdentifier = "MessageComposeMessageSegue"
    let showAttachmentsSegueIdentifier = "ShowAttachmentsSegue"

    var conversationId : Int64?
    var messageId : Int64?

    @IBOutlet var headerView: UIView!
    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var senderNameLabel: UILabel!
    @IBOutlet var senderOrganizationLabel: UILabel!
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var messageTextView: UITextView!

    // MARK: View lifecycle

    override func viewWillAppear(animated: Bool) {
        refreshContent()
    }

    // MARK: refresh content

    func refreshContent() {
        if let messageId = messageId {
            avatarImageView.image = KulloConnector.sharedInstance.getSenderAvatar(messageId, size: avatarImageView.frame.size)
            avatarImageView.showAsCircle()
            senderNameLabel.text = KulloConnector.sharedInstance.getSenderName(messageId)
            senderOrganizationLabel.text = KulloConnector.sharedInstance.getSenderOrganization(messageId)
            dateLabel.text = KulloConnector.sharedInstance.getMessageSentDate(messageId).formatWithSymbolicNames()
            messageTextView.attributedText = getMessageCombinedWithImprint(messageId)
            checkForAttachmentsAndSetButtonVisibilty()
        } else {
            log.error("In MessageViewController without messageId.")
        }    
    }

    func getMessageCombinedWithImprint(messageId: Int64) -> NSAttributedString {
        let message = KulloConnector.sharedInstance.getMessageText(messageId)
        let imprint = KulloConnector.sharedInstance.getSenderImprint(messageId)

        let messageAttributes = [
            NSForegroundColorAttributeName : UIColor.blackColor(),
            NSFontAttributeName : UIFont.systemFontOfSize(textSizeMessage)
        ]
        let messageText = NSMutableAttributedString(string: message, attributes: messageAttributes)

        let imprintAttributes = [NSForegroundColorAttributeName : UIColor.lightGrayColor(),
            NSFontAttributeName : UIFont.systemFontOfSize(textSizeMessage)]
        let imprintText = NSMutableAttributedString(string: imprint, attributes: imprintAttributes)

        messageText.appendAttributedString(NSAttributedString(string: "\n\n\n\n"))
        messageText.appendAttributedString(imprintText)

        return messageText
    }
    
    func checkForAttachmentsAndSetButtonVisibilty() {
        if let attachmentsButton = toolbarItems?.first {
            let attachmentIds = KulloConnector.sharedInstance.getMessageAttachmentsIds(messageId!)

            if attachmentIds.count > 0 {
                attachmentsButton.enabled = true
                attachmentsButton.tintColor = nil
            } else {
                attachmentsButton.enabled = false
                attachmentsButton.tintColor = UIColor.clearColor()
            }
        }
    }

    // MARK: Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == composeMessageSegueIdentifier {
            if let destination = segue.destinationViewController as? ComposeViewController {
                destination.convId = conversationId
            }
        } else if segue.identifier == showAttachmentsSegueIdentifier {
            if let navController = segue.destinationViewController as? UINavigationController {
                let attachmentsViewController = navController.viewControllers[0] as? AttachmentsViewController
                
                if let attachmentsViewController = attachmentsViewController {
                    attachmentsViewController.messageId = messageId
                }
            }
        }
    }
    
    
}
