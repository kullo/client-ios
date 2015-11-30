/* Copyright 2015 Kullo GmbH. All rights reserved. */

import LibKullo
import UIKit
import XCGLogger

class InboxViewController: UIViewController {

    // MARK: Properties
    private let conversationDetailSegueIdentifier = "ConversationDetailSegue"
    private static let inboxLoginSegueIdentifier = "InboxLoginSegue"
    private static let newConversationSegueIdentifier = "NewConversationSegue"

    @IBOutlet var swipeHintImageView: UIImageView!
    @IBOutlet var tableView: UITableView!

    private var conversationIds = [Int64]()
    var destinationConversationId: Int64?

    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: "conversationsRefresh:", forControlEvents: .ValueChanged)
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
        refreshControl.endRefreshing()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if destinationConversationId != nil {
            performSegueWithIdentifier(conversationDetailSegueIdentifier, sender: self)
            return
        }

        if !KulloConnector.sharedInstance.hasSession() {
            if !KulloConnector.sharedInstance.checkForStoredCredentialsAndCreateSession(self) {
                performSegueWithIdentifier(InboxViewController.inboxLoginSegueIdentifier, sender: self)
            }
        }
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)

        KulloConnector.sharedInstance.removeSyncDelegate(self)
        KulloConnector.sharedInstance.removeSessionEventsDelegate(self)
    }

    // MARK: Actions

    func conversationsRefresh(refreshControl: UIRefreshControl) {
        updateListAppearance()
        KulloConnector.sharedInstance.sync(.WithoutAttachments)
    }

    // MARK: Data

    func updateDataAndRefreshTable() {
        conversationIds = KulloConnector.sharedInstance.getAllConversationIdsSorted()
        tableView.reloadData()
        updateListAppearance()
    }

    func updateListAppearance() {
        let haveSession = KulloConnector.sharedInstance.hasSession()
        let conversationsEmpty = conversationIds.count == 0

        // show pull to refresh hint only when
        // * we have a session
        // * we have no conversations
        // * we're not refreshing
        let showSwipeHint = haveSession && conversationsEmpty && !refreshControl.refreshing
        if swipeHintImageView.hidden != !showSwipeHint {
            UIView.transitionWithView(
                swipeHintImageView,
                duration: 0.4,
                options: .TransitionCrossDissolve,
                animations: { self.swipeHintImageView.hidden = !showSwipeHint },
                completion: nil)
        }

        // show row separators only if we have conversations
        tableView.separatorStyle = conversationsEmpty ? .None : .SingleLine
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

    @IBAction func logout(sender: UIStoryboardSegue) {
        KulloConnector.sharedInstance.logout()

        // going to the login is handled automatically when this action has finished executing and this view is shown
    }
}

// MARK: NewConversationDelegate

extension InboxViewController : NewConversationDelegate {

    func newConversationCreatedWithId(convId: Int64) {
        destinationConversationId = convId
    }

}

// MARK: ClientCreateSessionDelegate

extension InboxViewController : ClientCreateSessionDelegate {

    func createSessionFinished(session: KASession) {
        KulloConnector.sharedInstance.setSession(session)
        updateDataAndRefreshTable()
    }

    func createSessionError(address: KAAddress, error: String) {
        let alertDialog = UIAlertController(
            title: NSLocalizedString("Couldn't load data", comment: ""),
            message: error,
            preferredStyle: .Alert);

        alertDialog.addAction(AlertHelper.getAlertOKAction({
            (action: UIAlertAction) in
            self.performSegueWithIdentifier(InboxViewController.inboxLoginSegueIdentifier, sender: self)
        }))

        presentViewController(alertDialog, animated: true, completion: nil);
    }

}

// MARK: Sync delegate

extension InboxViewController : SyncDelegate {

    func syncErrorDraftAttachmentsTooBig(convId: Int64) {
        refreshControl.endRefreshing()

        showInfoDialog(
            NSLocalizedString("Attachments too big", comment: ""),
            message: NSLocalizedString("Attachments at one conversation are too big.", comment: "")
        )
    }

    func syncFinished() {
        updateDataAndRefreshTable()
        refreshControl.endRefreshing()
    }

    func syncError(error: String) {
        refreshControl.endRefreshing()

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
        return conversationIds.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellIdentifier = "ConversationTableViewCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! ConversationTableViewCell

        let convId = conversationIds[indexPath.row]

        cell.inboxTitleLabel.text = KulloConnector.sharedInstance.getConversationNameOrPlaceHolder(convId)
        cell.inboxImageView.image = KulloConnector.sharedInstance.getConversationImage(convId, size: CGSizeMake(cell.inboxImageView.frame.size.width, cell.inboxImageView.frame.size.height))
        cell.inboxImageView.showAsCircle()
        cell.inboxDateLabel.text = KulloConnector.sharedInstance.getLatestMessageTimestamp(convId).formatWithSymbolicNames()

        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = UIEdgeInsetsZero
        cell.layoutMargins = UIEdgeInsetsZero

        return cell
    }

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        let convId = conversationIds[indexPath.row]
        let messageIds = KulloConnector.sharedInstance.getAllMessageIdsSorted(convId)
        return messageIds.count == 0
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == .Delete) {
            let convId = conversationIds[indexPath.row]
            KulloConnector.sharedInstance.removeConversation(convId)
            conversationIds = KulloConnector.sharedInstance.getAllConversationIdsSorted()
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
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

    func sessionEventMessageRemoved(convId: Int64, msgId: Int64) {
        updateDataAndRefreshTable()
    }
}
