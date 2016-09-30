/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import LibKullo
import UIKit
import XCGLogger

class InboxViewController: UIViewController {

    // MARK: Properties
    private let conversationDetailSegueIdentifier = "ConversationDetailSegue"
    private static let newConversationSegueIdentifier = "NewConversationSegue"

    private static let pullToRefreshCellId = "InboxPullToRefreshTableViewCell"
    private static let pullToRefreshCellHeight: CGFloat = 200
    private static let conversationCellId = "ConversationTableViewCell"
    private static let conversationCellHeight: CGFloat = 90

    @IBOutlet var tableView: UITableView!
    @IBOutlet var progressView: UIProgressView!

    private var conversationIds = [Int64]()
    private var shouldShowPullToRefreshHint = false
    var destinationConversationId: Int64?

    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshControlTriggered), forControlEvents: .ValueChanged)
        return refreshControl
    }()

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.addSubview(refreshControl)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        KulloConnector.sharedInstance.addSessionEventsDelegate(self)
        KulloConnector.sharedInstance.addSyncDelegate(self)
        updateDataAndRefreshTable()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if destinationConversationId != nil {
            performSegueWithIdentifier(conversationDetailSegueIdentifier, sender: self)
            return
        }
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
    }

    // MARK: Data

    func updateDataAndRefreshTable() {
        conversationIds = KulloConnector.sharedInstance.getAllConversationIdsSorted()

        let haveSession = KulloConnector.sharedInstance.hasSession()
        let haveConversations = conversationIds.count > 0
        let syncIsRunning = KulloConnector.sharedInstance.isSyncRunning()
        shouldShowPullToRefreshHint = haveSession && !haveConversations && !syncIsRunning

        if shouldShowPullToRefreshHint {
            tableView.rowHeight = InboxViewController.pullToRefreshCellHeight
        } else {
            tableView.rowHeight = InboxViewController.conversationCellHeight
        }

        tableView.reloadData()
        updateListAppearance()
    }

    func updateSyncProgress() {
        progressView.progress = KulloConnector.sharedInstance.getSyncProgress()
    }

    func updateListAppearance() {
        let haveConversations = conversationIds.count > 0
        let syncIsRunning = KulloConnector.sharedInstance.isSyncRunning()

        if haveConversations {
            refreshControl.endRefreshing()
        }

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

        // show row separators only if we have conversations
        tableView.separatorStyle = haveConversations ? .SingleLine : .None
    }

    // MARK: Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let segueIdentifier = segue.identifier {
            switch segueIdentifier {

            case conversationDetailSegueIdentifier:
                let destination = segue.destinationViewController as! MessagesViewController
                if let convId = destinationConversationId {
                    destination.convId = convId
                    destinationConversationId = nil
                } else if let conversationIndex = tableView.indexPathForSelectedRow?.row {
                    destination.convId = conversationIds[conversationIndex]
                }

            case InboxViewController.newConversationSegueIdentifier:
                let destination = segue.destinationViewController.childViewControllers.first
                    as! NewConversationViewController
                destination.delegate = self

            default: break
            }
        }
    }

}

// MARK: NewConversationDelegate

extension InboxViewController : NewConversationDelegate {

    func newConversationCreatedWithId(convId: Int64) {
        destinationConversationId = convId
    }

}

// MARK: Sync delegate

extension InboxViewController : SyncDelegate {

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
        refreshControl.endRefreshing()
        updateListAppearance()
    }

    func syncError(error: String) {
        refreshControl.endRefreshing()
        updateListAppearance()

        showInfoDialog(
            NSLocalizedString("Synchronization error", comment: ""),
            message: error
        )
    }
}

// MARK: Tableview datasource and delegate

extension InboxViewController : UITableViewDataSource, UITableViewDelegate {

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if shouldShowPullToRefreshHint {
            return 1
        }
        return conversationIds.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if shouldShowPullToRefreshHint {
            return tableView.dequeueReusableCellWithIdentifier(InboxViewController.pullToRefreshCellId, forIndexPath: indexPath)
        }

        let cell = tableView.dequeueReusableCellWithIdentifier(InboxViewController.conversationCellId, forIndexPath: indexPath) as! ConversationTableViewCell

        let convId = conversationIds[indexPath.row]

        // let avatar size calculation happen
        cell.inboxImageView.layoutIfNeeded()
        cell.inboxImageView.image = KulloConnector.sharedInstance.getConversationImage(convId, size: cell.inboxImageView.frame.size)
        cell.inboxImageView.showAsCircle()

        cell.inboxTitleLabel.text = KulloConnector.sharedInstance.getConversationNameOrPlaceHolder(convId)
        cell.inboxDateLabel.text = KulloConnector.sharedInstance.getLatestMessageTimestamp(convId).formatWithSymbolicNames()
        cell.inboxUnreadLabel.hidden = KulloConnector.sharedInstance.getConversationUnread(convId) == 0

        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = UIEdgeInsetsZero
        cell.layoutMargins = UIEdgeInsetsZero

        return cell
    }

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return !shouldShowPullToRefreshHint
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == .Delete) {
            let convId = conversationIds[indexPath.row]
            let doDelete = {
                self.conversationIds.removeAtIndex(indexPath.row)
                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
                KulloConnector.sharedInstance.removeConversation(convId)
            }

            if KulloConnector.sharedInstance.getAllMessageIdsSorted(convId).count == 0 {
                doDelete()
            } else {
                showConfirmationDialog(
                    NSLocalizedString("delete_conv_title", comment: ""),
                    message: NSLocalizedString("delete_conv_message", comment: ""),
                    confirmationButtonText: NSLocalizedString("delete_conv_action", comment: "")) { _ in
                    doDelete()
                }
            }
        }
    }

}

// MARK: SessionEventsDelegate

extension InboxViewController : SessionEventsDelegate {

    func sessionEventConversationAdded(convId: Int64) {
        updateDataAndRefreshTable()
    }

    func sessionEventConversationChanged(convId: Int64) {
        updateDataAndRefreshTable()
    }

    func sessionEventConversationRemoved(convId: Int64) {
        updateDataAndRefreshTable()
    }

    func sessionEventMessageAdded(convId: Int64, msgId: Int64) {
        updateDataAndRefreshTable()
    }

    func sessionEventMessageStateChanged(convId: Int64, msgId: Int64) {
        updateDataAndRefreshTable()
    }

    func sessionEventMessageRemoved(convId: Int64, msgId: Int64) {
        updateDataAndRefreshTable()
    }
}
