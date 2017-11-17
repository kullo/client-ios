/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit
import XCGLogger

class MessagesViewController: UIViewController {

    // MARK: Properties
    private static let writeNewMessageCellId = "WriteNewMessageTableViewCell"
    private static let messageCellId = "MessagesTableViewCell"
    private static let openSearchSegueIdentifier = "MessagesOpenSearch"

    var convId: Int64?
    private var messageIds = [Int64]()
    private var hideHint = false
    private var visibleSinceMap = [Int64: UInt64]()
    private var visibleSinceTimer: Timer?

    private var isShown = false {
        didSet {
            guard isShown != oldValue else { return }
            updateVisibleSinceTimer(appState: UIApplication.shared.applicationState)
        }
    }

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
        headerView.frame.size.height = ceil(headerHeight)

        // necessary to inform tableView of headerView's height change
        tableView.tableHeaderView = headerView
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        KulloConnector.shared.addSessionEventsDelegate(self)
        KulloConnector.shared.addSyncDelegate(self)
        updateDataAndRefreshTable()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        isShown = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSNotification.Name.UIApplicationDidBecomeActive,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: NSNotification.Name.UIApplicationWillResignActive,
            object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        isShown = false
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name.UIApplicationDidBecomeActive,
            object: nil)
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name.UIApplicationWillResignActive,
            object: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        KulloConnector.shared.removeSyncDelegate(self)
        KulloConnector.shared.removeSessionEventsDelegate(self)
    }

    // MARK: Actions

    @objc private func refreshControlTriggered(_ refreshControl: UIRefreshControl) {
        KulloConnector.shared.sync(.withoutAttachments)
        updateListAppearance()
        refreshControl.endRefreshing()
    }

    @objc private func appDidBecomeActive() {
        updateVisibleSinceTimer(appState: .active)
    }

    @objc private func appWillResignActive() {
        updateVisibleSinceTimer(appState: .inactive)
    }

    private func updateVisibleSinceTimer(appState: UIApplicationState) {
        if isShown && appState == .active {
            visibleSinceMap.removeAll()
            visibleSinceTimer?.invalidate()
            visibleSinceTimer = Timer.scheduledTimer(
                timeInterval: 0.5,
                target: self,
                selector: #selector(updateVisibleSinceMap),
                userInfo: nil,
                repeats: true
            )
            visibleSinceTimer?.fire()

        } else {
            visibleSinceTimer?.invalidate()
            visibleSinceTimer = nil
        }
    }

    @objc private func updateVisibleSinceMap() {
        guard let indexPathsForVisibleRows = tableView.indexPathsForVisibleRows else { return }

        // prevent crash due to TableView containing empty state
        guard messageIds.count > 0 else {
            visibleSinceMap.removeAll()
            return
        }

        var markedMessagesAsRead = false
        var newVisibleSinceMap = [Int64: UInt64]()
        for indexPath in indexPathsForVisibleRows {
            let messageId = messageIds[indexPath.row]

            if tableView.bounds.contains(tableView.rectForRow(at: indexPath)),
                KulloConnector.shared.getMessageUnread(messageId),
                !KulloConnector.shared.hasAttachments(messageId),
                !isTextTruncated(indexPath: indexPath) {

                if let oldVisibleSince = visibleSinceMap[messageId] {
                    if secondsSince(machTime: oldVisibleSince) >= 3 {
                        KulloConnector.shared.setMessageUnread(messageId, value: false)
                        markedMessagesAsRead = true
                        log.debug("marked \(messageId) as read")

                    } else {
                        newVisibleSinceMap[messageId] = oldVisibleSince
                    }

                } else {
                    newVisibleSinceMap[messageId] = mach_absolute_time()
                }
            }
        }
        visibleSinceMap = newVisibleSinceMap

        if markedMessagesAsRead {
            updateDataAndRefreshTable()
        }
    }

    private func isTextTruncated(indexPath: IndexPath) -> Bool {
        guard let cell = tableView.cellForRow(at: indexPath) as? MessagesTableViewCell else {
            return false
        }

        cell.layoutIfNeeded()
        return cell.messageTextLabel.isTruncated
    }

    private static let machTimeToSecondsFactor: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom) / 1_000_000_000
    }()

    private func secondsSince(machTime: UInt64) -> Double {
        return Double(mach_absolute_time() - machTime) * MessagesViewController.machTimeToSecondsFactor
    }

    // MARK: Data

    func updateDataAndRefreshTable() {
        guard let convId = convId else {
            log.error("MessagesViewController without convId.")
            return
        }

        let participants = KulloConnector.shared.getParticipantAdresses(convId)
            .map({$0.description()})
            .sorted()
            .joined(separator: ", ")
        let prefix = NSLocalizedString("conversation_with", comment: "")
        headerView.label.text = "\(prefix) \(participants)"

        messageIds = KulloConnector.shared.getAllMessageIdsSorted(convId)
        navigationItem.title = KulloConnector.shared.getConversationNameOrPlaceHolder(convId)
        tableView.reloadData()
        updateListAppearance()
    }

    func updateSyncProgress() {
        progressView.progress = KulloConnector.shared.getSyncProgress()
    }

    func updateListAppearance() {
        let syncIsRunning = KulloConnector.shared.isSyncRunning()

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
        } else if segue.identifier == MessagesViewController.openSearchSegueIdentifier {
            if let destination = segue.destination as? MessageSearchViewController {
                destination.conversationFilter = convId
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

        let messageText = KulloConnector.shared.getMessageText(messageId)
        let messageTextWithoutNewLine = messageText.replacingOccurrences(
            of: "\\n+",
            with: " ",
            options: .regularExpression,
            range: messageText.startIndex..<messageText.endIndex
        )

        // let avatar size calculation happen
        cell.messageImageView.layoutIfNeeded()
        cell.messageImageView.image = KulloConnector.shared.getSenderAvatar(messageId, size: cell.messageImageView.frame.size)
        cell.messageImageView.showAsCircle()

        cell.messageName.text = KulloConnector.shared.getSenderName(messageId)
        cell.messageOrganization.text = KulloConnector.shared.getSenderOrganization(messageId)
        cell.messageDateLabel.text = KulloConnector.shared.getMessageReceivedDate(messageId).formatWithSymbolicNames()
        cell.messageUnreadLabel.isHidden = !KulloConnector.shared.getMessageUnread(messageId)
        cell.hasAttachmentsIcon.isHidden = !KulloConnector.shared.hasAttachments(messageId)
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
            KulloConnector.shared.removeMessage(msgId)
            messageIds = KulloConnector.shared.getAllMessageIdsSorted(convId!)
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
