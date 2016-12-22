/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import UIKit
import XCGLogger

class MessagesViewController: UIViewController {

    // MARK: Properties
    fileprivate static let writeNewMessageCellId = "WriteNewMessageTableViewCell"
    fileprivate static let messageCellId = "MessagesTableViewCell"
    
    var convId: Int64?
    fileprivate var messageIds = [Int64]()
    fileprivate var hideHint = false

    @IBOutlet var tableView: UITableView!
    @IBOutlet var progressView: UIProgressView!
    var headerView: MessagesHeaderView!

    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshControlTriggered), for: .valueChanged)
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
        let headerHeight = headerView.systemLayoutSizeFitting(UILayoutFittingCompressedSize).height
        headerView.frame.size.height = headerHeight
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        KulloConnector.sharedInstance.addSessionEventsDelegate(self)
        KulloConnector.sharedInstance.addSyncDelegate(self)
        updateDataAndRefreshTable()
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
            .sorted()
            .joined(separator: ", ")
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

        if progressView.isHidden == syncIsRunning {
            UIView.transition(
                with: progressView,
                duration: 0.4,
                options: .transitionCrossDissolve,
                animations: { self.progressView.isHidden = !syncIsRunning },
                completion: nil)
        }
    }

    func shouldShowWriteMessageHint() -> Bool {
        return !hideHint && messageIds.count == 0
    }

    // MARK: Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == showMessageSegueIdentifier {
            if let destination = segue.destination as? MessageViewController {
                if let index = tableView.indexPathForSelectedRow?.row {
                    destination.conversationId = convId
                    destination.messageId = messageIds[index]
                }
            }
        } else if segue.identifier == composeMessageSegueIdentifier {
            if let destination = segue.destination as? ComposeViewController {
                destination.convId = convId
            }
        }
    }

}

extension MessagesViewController: UITableViewDataSource, UITableViewDelegate {

    // MARK: Tableview datasource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if shouldShowWriteMessageHint() {
            return 1
        }
        return messageIds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if shouldShowWriteMessageHint() {
            return tableView.dequeueReusableCell(withIdentifier: MessagesViewController.writeNewMessageCellId, for: indexPath)
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: MessagesViewController.messageCellId, for: indexPath) as! MessagesTableViewCell

        let messageId = messageIds[indexPath.row]

        let messageText = KulloConnector.sharedInstance.getMessageText(messageId)
        let messageTextWithoutNewLine = messageText.replacingOccurrences(
            of: "\\n+",
            with: " ",
            options: .regularExpression,
            range: messageText.startIndex..<messageText.endIndex
        )

        // let avatar size calculation happen
        cell.messageImageView.layoutIfNeeded()
        cell.messageImageView.image = KulloConnector.sharedInstance.getSenderAvatar(messageId, size: cell.messageImageView.frame.size)
        cell.messageImageView.showAsCircle()

        cell.messageName.text = KulloConnector.sharedInstance.getSenderName(messageId)
        cell.messageOrganization.text = KulloConnector.sharedInstance.getSenderOrganization(messageId)
        cell.messageDateLabel.text = KulloConnector.sharedInstance.getMessageReceivedDate(messageId).formatWithSymbolicNames()
        cell.messageUnreadLabel.isHidden = !KulloConnector.sharedInstance.getMessageUnread(messageId)
        cell.messageTextLabel.text = messageTextWithoutNewLine

        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = UIEdgeInsets.zero
        cell.layoutMargins = UIEdgeInsets.zero

        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !shouldShowWriteMessageHint()
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete) {
            // We need to hide the hint because UITableView expects that the number of rows
            // after deletion is one less than before, which wouldn't be the case if we deleted
            // the last row and then showed the hint
            hideHint = true

            let msgId = messageIds[indexPath.row]
            KulloConnector.sharedInstance.removeMessage(msgId)
            messageIds = KulloConnector.sharedInstance.getAllMessageIdsSorted(convId!)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

}

extension MessagesViewController: SessionEventsDelegate {

    func sessionEventConversationRemoved(_ convId: Int64) {
        if convId == self.convId! {
            self.navigationController!.popViewController(animated: true)
        }
    }

    func sessionEventMessageAdded(_ convId: Int64, msgId: Int64) {
        if convId == self.convId! {
            updateDataAndRefreshTable()
        }
    }

    func sessionEventMessageStateChanged(_ convId: Int64, msgId: Int64) {
        if convId == self.convId! {
            updateDataAndRefreshTable()
        }
    }

    func sessionEventMessageRemoved(_ convId: Int64, msgId: Int64) {
        if convId == self.convId! {
            updateDataAndRefreshTable()
        }
    }

}

// MARK: Sync delegate

extension MessagesViewController: SyncDelegate {

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
        updateListAppearance()
    }

    func syncError(_ error: String) {
        updateListAppearance()

        showInfoDialog(
            NSLocalizedString("Synchronization error", comment: ""),
            message: error
        )
    }
}
