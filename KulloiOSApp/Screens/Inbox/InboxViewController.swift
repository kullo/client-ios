/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import LibKullo
import UIKit
import XCGLogger

class InboxViewController: UIViewController {

    // MARK: Properties
    fileprivate let conversationDetailSegueIdentifier = "ConversationDetailSegue"
    fileprivate static let newConversationSegueIdentifier = "NewConversationSegue"

    fileprivate static let pullToRefreshCellId = "InboxPullToRefreshTableViewCell"
    fileprivate static let pullToRefreshCellHeight: CGFloat = 200
    fileprivate static let conversationCellId = "ConversationTableViewCell"
    fileprivate static let conversationCellHeight: CGFloat = 90

    @IBOutlet var tableView: UITableView!
    @IBOutlet var progressView: UIProgressView!

    fileprivate var conversationIds = [Int64]()
    fileprivate var shouldShowPullToRefreshHint = false
    var destinationConversationId: Int64?

    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshControlTriggered), for: .valueChanged)
        return refreshControl
    }()

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.addSubview(refreshControl)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        KulloConnector.sharedInstance.addSessionEventsDelegate(self)
        KulloConnector.sharedInstance.addSyncDelegate(self)
        updateDataAndRefreshTable()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if destinationConversationId != nil {
            performSegue(withIdentifier: conversationDetailSegueIdentifier, sender: self)
            return
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        KulloConnector.sharedInstance.removeSyncDelegate(self)
        KulloConnector.sharedInstance.removeSessionEventsDelegate(self)
    }

    // MARK: Actions

    func refreshControlTriggered(_ refreshControl: UIRefreshControl) {
        KulloConnector.sharedInstance.sync(.withoutAttachments)
        updateListAppearance()
    }

    // MARK: Data

    func updateDataAndRefreshTable() {
        conversationIds = KulloConnector.sharedInstance.getAllConversationIdsSorted()

        let haveConversations = conversationIds.count > 0
        let syncIsRunning = KulloConnector.sharedInstance.isSyncRunning()
        shouldShowPullToRefreshHint = !haveConversations && !syncIsRunning

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

        if progressView.isHidden == syncIsRunning {
            UIView.transition(
                with: progressView,
                duration: 0.4,
                options: .transitionCrossDissolve,
                animations: { self.progressView.isHidden = !syncIsRunning },
                completion: nil)
        }

        // show row separators only if we have conversations
        tableView.separatorStyle = haveConversations ? .singleLine: .none
    }

    // MARK: Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let segueIdentifier = segue.identifier {
            switch segueIdentifier {

            case conversationDetailSegueIdentifier:
                let destination = segue.destination as! MessagesViewController
                if let convId = destinationConversationId {
                    destination.convId = convId
                    destinationConversationId = nil
                } else if let conversationIndex = tableView.indexPathForSelectedRow?.row {
                    destination.convId = conversationIds[conversationIndex]
                }

            case InboxViewController.newConversationSegueIdentifier:
                let destination = segue.destination.childViewControllers.first
                    as! NewConversationViewController
                destination.delegate = self

            default: break
            }
        }
    }

}

// MARK: NewConversationDelegate

extension InboxViewController: NewConversationDelegate {

    func newConversationCreatedWithId(_ convId: Int64) {
        destinationConversationId = convId
    }

}

// MARK: Sync delegate

extension InboxViewController: SyncDelegate {

    func syncStarted() {
        updateListAppearance()
    }

    func syncProgressed() {
        updateSyncProgress()
    }

    func syncDraftAttachmentsTooBig(_ convId: Int64) {
        showInfoDialog(
            NSLocalizedString("Attachments too big", comment: ""),
            message: NSLocalizedString("Attachments at one conversation are too big.", comment: "")
        )
    }

    func syncFinished() {
        refreshControl.endRefreshing()
        updateListAppearance()
    }

    func syncError(_ error: String) {
        refreshControl.endRefreshing()
        updateListAppearance()

        showInfoDialog(
            NSLocalizedString("Synchronization error", comment: ""),
            message: error
        )
    }
}

// MARK: Tableview datasource and delegate

extension InboxViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if shouldShowPullToRefreshHint {
            return 1
        }
        return conversationIds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if shouldShowPullToRefreshHint {
            return tableView.dequeueReusableCell(withIdentifier: InboxViewController.pullToRefreshCellId, for: indexPath)
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: InboxViewController.conversationCellId, for: indexPath) as! ConversationTableViewCell

        let convId = conversationIds[indexPath.row]

        // let avatar size calculation happen
        cell.inboxImageView.layoutIfNeeded()
        cell.inboxImageView.image = KulloConnector.sharedInstance.getConversationImage(convId, size: cell.inboxImageView.frame.size)
        cell.inboxImageView.showAsCircle()

        cell.inboxTitleLabel.text = KulloConnector.sharedInstance.getConversationNameOrPlaceHolder(convId)
        cell.inboxDateLabel.text = KulloConnector.sharedInstance.getLatestMessageTimestamp(convId).formatWithSymbolicNames()
        cell.inboxUnreadLabel.isHidden = KulloConnector.sharedInstance.getConversationUnread(convId) == 0

        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = UIEdgeInsets.zero
        cell.layoutMargins = UIEdgeInsets.zero

        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !shouldShowPullToRefreshHint
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete) {
            let convId = conversationIds[indexPath.row]
            let doDelete = {
                self.conversationIds.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
                KulloConnector.sharedInstance.removeConversation(convId)
            }

            let messagesToDelete = KulloConnector.sharedInstance.getAllMessageIdsSorted(convId).count
            if messagesToDelete == 0 {
                doDelete()
            } else {
                let warningMessage: String
                if messagesToDelete == 1 {
                    warningMessage = NSLocalizedString("delete_conv_message_onemsg", comment: "")
                } else {
                    warningMessage = String.localizedStringWithFormat(
                        NSLocalizedString("delete_conv_message_multiplemsgs", comment: ""),
                        messagesToDelete
                    )
                }
                showConfirmationDialog(
                    NSLocalizedString("delete_conv_title", comment: ""),
                    message: warningMessage,
                    confirmationButtonText: NSLocalizedString("delete_conv_action", comment: "")) { _ in
                    doDelete()
                }
            }
        }
    }

}

// MARK: SessionEventsDelegate

extension InboxViewController: SessionEventsDelegate {

    func sessionEventConversationAdded(_ convId: Int64) {
        updateDataAndRefreshTable()
    }

    func sessionEventConversationChanged(_ convId: Int64) {
        updateDataAndRefreshTable()
    }

    func sessionEventConversationRemoved(_ convId: Int64) {
        updateDataAndRefreshTable()
    }

    func sessionEventMessageAdded(_ convId: Int64, msgId: Int64) {
        updateDataAndRefreshTable()
    }

    func sessionEventMessageStateChanged(_ convId: Int64, msgId: Int64) {
        updateDataAndRefreshTable()
    }

    func sessionEventMessageRemoved(_ convId: Int64, msgId: Int64) {
        updateDataAndRefreshTable()
    }
}
