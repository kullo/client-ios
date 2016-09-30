/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import UIKit
import XCGLogger

class MessagesViewController: UIViewController {

    // MARK: Properties
    private static let writeNewMessageCellId = "WriteNewMessageTableViewCell"
    private static let messageCellId = "MessagesTableViewCell"
    
    var convId : Int64?
    private var messageIds = [Int64]()
    private var hideHint = false

    @IBOutlet var tableView: UITableView!
    @IBOutlet var progressView: UIProgressView!
    var headerView: MessagesHeaderView!

    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshControlTriggered), forControlEvents: .ValueChanged)
        return refreshControl
    }()

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        headerView = tableView.tableHeaderView as! MessagesHeaderView
        tableView.addSubview(refreshControl)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        headerView.setNeedsLayout()
        headerView.layoutIfNeeded()
        let headerHeight = headerView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height
        headerView.frame.size.height = headerHeight
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        KulloConnector.sharedInstance.addSessionEventsDelegate(self)
        KulloConnector.sharedInstance.addSyncDelegate(self)
        updateDataAndRefreshTable()
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)

        KulloConnector.sharedInstance.removeSyncDelegate(self)
        KulloConnector.sharedInstance.removeSessionEventsDelegate(self)
    }

    // MARK: Actions

    func refreshControlTriggered(refreshControl: UIRefreshControl) {
        KulloConnector.sharedInstance.sync(.WithoutAttachments)
        updateListAppearance()
        refreshControl.endRefreshing()
    }

    // MARK: Data

    func updateDataAndRefreshTable() {
        guard let convId = convId else {
            log.error("MessagesViewController without convId.")
            return
        }

        let participants = KulloConnector.sharedInstance.getParticipantAdresses(convId)
            .map({$0.toString()})
            .sort()
            .joinWithSeparator(", ")
        let prefix = NSLocalizedString("conversation_with", comment: "")
        headerView.label.text = "\(prefix) \(participants)"

        messageIds = KulloConnector.sharedInstance.getAllMessageIdsSorted(convId)
        navigationItem.title = KulloConnector.sharedInstance.getConversationNameOrPlaceHolder(convId)
        tableView.reloadData()
        updateListAppearance()
    }

    func updateSyncProgress() {
        progressView.progress = KulloConnector.sharedInstance.getSyncProgress()
    }

    func updateListAppearance() {
        let syncIsRunning = KulloConnector.sharedInstance.isSyncRunning()

        if syncIsRunning {
            updateSyncProgress()
        }

        if progressView.hidden == syncIsRunning {
            UIView.transitionWithView(
                progressView,
                duration: 0.4,
                options: .TransitionCrossDissolve,
                animations: { self.progressView.hidden = !syncIsRunning },
                completion: nil)
        }
    }

    func shouldShowWriteMessageHint() -> Bool {
        return !hideHint && messageIds.count == 0
    }

    // MARK: Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == showMessageSegueIdentifier {
            if let destination = segue.destinationViewController as? MessageViewController {
                if let index = tableView.indexPathForSelectedRow?.row {
                    destination.conversationId = convId
                    destination.messageId = messageIds[index]
                }
            }
        } else if segue.identifier == composeMessageSegueIdentifier {
            if let destination = segue.destinationViewController as? ComposeViewController {
                destination.convId = convId
            }
        }
    }

}

extension MessagesViewController : UITableViewDataSource, UITableViewDelegate {

    // MARK: Tableview datasource

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if shouldShowWriteMessageHint() {
            return 1
        }
        return messageIds.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if shouldShowWriteMessageHint() {
            return tableView.dequeueReusableCellWithIdentifier(MessagesViewController.writeNewMessageCellId, forIndexPath: indexPath)
        }

        let cell = tableView.dequeueReusableCellWithIdentifier(MessagesViewController.messageCellId, forIndexPath: indexPath) as! MessagesTableViewCell

        let messageId = messageIds[indexPath.row]

        let messageText = KulloConnector.sharedInstance.getMessageText(messageId)
        let messageTextWithoutNewLine = messageText.stringByReplacingOccurrencesOfString("\\n+", withString: " ", options:NSStringCompareOptions.RegularExpressionSearch, range: messageText.startIndex ..< messageText.endIndex)

        // let avatar size calculation happen
        cell.messageImageView.layoutIfNeeded()
        cell.messageImageView.image = KulloConnector.sharedInstance.getSenderAvatar(messageId, size: cell.messageImageView.frame.size)
        cell.messageImageView.showAsCircle()

        cell.messageName.text = KulloConnector.sharedInstance.getSenderName(messageId)
        cell.messageOrganization.text = KulloConnector.sharedInstance.getSenderOrganization(messageId)
        cell.messageDateLabel.text = KulloConnector.sharedInstance.getMessageReceivedDate(messageId).formatWithSymbolicNames()
        cell.messageUnreadLabel.hidden = !KulloConnector.sharedInstance.getMessageUnread(messageId)
        cell.messageTextLabel.text = messageTextWithoutNewLine

        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = UIEdgeInsetsZero
        cell.layoutMargins = UIEdgeInsetsZero

        return cell
    }

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return !shouldShowWriteMessageHint()
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == .Delete) {
            // We need to hide the hint because UITableView expects that the number of rows
            // after deletion is one less than before, which wouldn't be the case if we deleted
            // the last row and then showed the hint
            hideHint = true

            let msgId = messageIds[indexPath.row]
            KulloConnector.sharedInstance.removeMessage(msgId)
            messageIds = KulloConnector.sharedInstance.getAllMessageIdsSorted(convId!)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
        }
    }

}

extension MessagesViewController : SessionEventsDelegate {

    func sessionEventConversationRemoved(convId: Int64) {
        if convId == self.convId! {
            self.navigationController!.popViewControllerAnimated(true)
        }
    }

    func sessionEventMessageAdded(convId: Int64, msgId: Int64) {
        if convId == self.convId! {
            updateDataAndRefreshTable()
        }
    }

    func sessionEventMessageStateChanged(convId: Int64, msgId: Int64) {
        if convId == self.convId! {
            updateDataAndRefreshTable()
        }
    }

    func sessionEventMessageRemoved(convId: Int64, msgId: Int64) {
        if convId == self.convId! {
            updateDataAndRefreshTable()
        }
    }

}

// MARK: Sync delegate

extension MessagesViewController : SyncDelegate {

    func syncStarted() {
        updateListAppearance()
    }

    func syncProgressed() {
        updateSyncProgress()
    }

    func syncDraftAttachmentsTooBig(convId: Int64) {
        showInfoDialog(
            NSLocalizedString("Attachments too big", comment: ""),
            message: NSLocalizedString("Attachments at one conversation are too big.", comment: "")
        )
    }

    func syncFinished() {
        updateListAppearance()
    }

    func syncError(error: String) {
        updateListAppearance()

        showInfoDialog(
            NSLocalizedString("Synchronization error", comment: ""),
            message: error
        )
    }
}
