/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import LibKullo
import UIKit

class InboxViewController: UIViewController {

    // MARK: Properties
    private static let pullToRefreshCellId = "InboxPullToRefreshTableViewCell"
    private static let pullToRefreshCellHeight: CGFloat = 200
    private static let conversationCellId = "ConversationTableViewCell"
    private static let conversationCellHeight: CGFloat = 90

    @IBOutlet var tableView: UITableView!
    @IBOutlet var progressView: UIProgressView!

    private var conversationIds = [Int64]()
    private var shouldShowPullToRefreshHint = false
    private var destinationConversationId: Int64?

    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshControlTriggered), for: .valueChanged)
        return refreshControl
    }()

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: #imageLiteral(resourceName: "more_icon"), style: .plain, target: self, action: #selector(moreTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .search, target: self, action: #selector(searchTapped))

        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTapped)),
        ]

        tableView.addSubview(refreshControl)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        KulloConnector.shared.addSessionEventsDelegate(self)
        KulloConnector.shared.addSyncDelegate(self)
        updateDataAndRefreshTable()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let convId = destinationConversationId {
            let vc = StoryboardUtil.instantiate(MessagesViewController.self)
            vc.convId = convId
            destinationConversationId = nil
            navigationController?.pushViewController(vc, animated: true)
            return
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        KulloConnector.shared.removeSyncDelegate(self)
        KulloConnector.shared.removeSessionEventsDelegate(self)
    }

    // MARK: Actions
    @objc private func addTapped(_ sender: UIBarButtonItem) {
        let vc = StoryboardUtil.instantiate(NewConversationViewController.self)
        vc.delegate = self
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    @objc private func moreTapped(_ sender: UIBarButtonItem) {
        let vc = StoryboardUtil.instantiate(MoreViewController.self)
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    @objc private func searchTapped(_ sender: UIBarButtonItem) {
        let vc = StoryboardUtil.instantiate(MessageSearchViewController.self)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func refreshControlTriggered(_ refreshControl: UIRefreshControl) {
        KulloConnector.shared.sync(.withoutAttachments)
        updateListAppearance()
    }

    // MARK: Data

    func updateDataAndRefreshTable() {
        conversationIds = KulloConnector.shared.getAllConversationIdsSorted()

        let haveConversations = conversationIds.count > 0
        let syncIsRunning = KulloConnector.shared.isSyncRunning()
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
        progressView.progress = KulloConnector.shared.getSyncProgress()
    }

    func updateListAppearance() {
        let haveConversations = conversationIds.count > 0
        let syncIsRunning = KulloConnector.shared.isSyncRunning()

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
        cell.inboxImageView.image = KulloConnector.shared.getConversationImage(convId, size: cell.inboxImageView.frame.size)
        cell.inboxImageView.showAsCircle()

        cell.inboxTitleLabel.text = KulloConnector.shared.getConversationNameOrPlaceHolder(convId)
        cell.inboxDateLabel.text = KulloConnector.shared.getLatestMessageTimestamp(convId).formatWithSymbolicNames()
        cell.inboxUnreadLabel.isHidden = KulloConnector.shared.getConversationUnread(convId) == 0

        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = UIEdgeInsets.zero
        cell.layoutMargins = UIEdgeInsets.zero

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc = StoryboardUtil.instantiate(MessagesViewController.self)
        vc.convId = conversationIds[indexPath.row]
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return !shouldShowPullToRefreshHint
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete) {
            let convId = conversationIds[indexPath.row]
            let doDelete = {
                self.conversationIds.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
                KulloConnector.shared.removeConversation(convId)
            }

            let messagesToDelete = KulloConnector.shared.getAllMessageIdsSorted(convId).count
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
