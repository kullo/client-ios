/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit

class MessageViewController: UIViewController {

    // MARK: Properties

    var conversationId: Int64?
    var messageId: Int64?

    @IBOutlet var headerView: UIView!
    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var senderNameLabel: UILabel!
    @IBOutlet var senderOrganizationLabel: UILabel!
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var messageTextView: UITextView!

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .organize, target: self, action: #selector(openAttachmentsTapped)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(composeTapped)),
        ]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshContent()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        KulloConnector.shared.setMessageUnread(messageId!, value: false)
    }

    @objc private func composeTapped() {
        let vc = StoryboardUtil.instantiate(ComposeViewController.self)
        vc.convId = conversationId
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openAttachmentsTapped() {
        let vc = MessageAttachmentsViewController()
        vc.messageId = messageId
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    // MARK: refresh content

    func refreshContent() {
        if let messageId = messageId {

            // let avatar size calculation happen
            avatarImageView.layoutIfNeeded()
            avatarImageView.image = KulloConnector.shared.getSenderAvatar(messageId, size: avatarImageView.frame.size)
            avatarImageView.showAsCircle()

            senderNameLabel.text = KulloConnector.shared.getSenderName(messageId)
            senderOrganizationLabel.text = KulloConnector.shared.getSenderOrganization(messageId)
            dateLabel.text = KulloConnector.shared.getMessageReceivedDate(messageId).formatWithDateAndTime()
            messageTextView.attributedText = getMessageCombinedWithImprint(messageId)
            checkForAttachmentsAndSetButtonVisibilty()
        } else {
            log.error("In MessageViewController without messageId.")
        }    
    }

    func getMessageCombinedWithImprint(_ messageId: Int64) -> NSAttributedString {
        let message = KulloConnector.shared.getMessageText(messageId)
        let imprint = KulloConnector.shared.getSenderImprint(messageId)

        let messageAttributes: [NSAttributedStringKey: Any] = [
            .foregroundColor: UIColor.black,
            .font: UIFont.systemFont(ofSize: textSizeMessage),
        ]
        let messageText = NSMutableAttributedString(string: message, attributes: messageAttributes)

        let imprintAttributes: [NSAttributedStringKey: Any] = [
            .foregroundColor: UIColor.lightGray,
            .font: UIFont.systemFont(ofSize: textSizeMessage),
        ]
        let imprintText = NSMutableAttributedString(string: imprint, attributes: imprintAttributes)

        messageText.append(NSAttributedString(string: "\n\n\n\n"))
        messageText.append(imprintText)

        return messageText
    }
    
    func checkForAttachmentsAndSetButtonVisibilty() {
        if let attachmentsButton = toolbarItems?.first {
            let attachmentIds = KulloConnector.shared.getMessageAttachmentIds(messageId!)

            if attachmentIds.count > 0 {
                attachmentsButton.isEnabled = true
                attachmentsButton.tintColor = nil
            } else {
                attachmentsButton.isEnabled = false
                attachmentsButton.tintColor = UIColor.clear
            }
        }
    }
}
