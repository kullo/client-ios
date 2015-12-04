/* Copyright 2015 Kullo GmbH. All rights reserved. */

import UIKit
import XCGLogger

class MessagesViewController: UIViewController {

    // MARK: Properties
    
    var convId : Int64?
    private var messageIds = [Int64]()
    @IBOutlet var tableView: UITableView!

    // MARK: View lifecycle

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        KulloConnector.sharedInstance.addSessionEventsDelegate(self)
        updateDatabasisAndRefreshTable()
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)

        KulloConnector.sharedInstance.removeSessionEventsDelegate(self)
    }

    // MARK: Databasis

    func updateDatabasisAndRefreshTable() {
        if let convId = convId {
            messageIds = KulloConnector.sharedInstance.getAllMessageIdsSorted(convId)
            navigationItem.title = KulloConnector.sharedInstance.getConversationNameOrPlaceHolder(convId)
            tableView.reloadData()
        } else {
            log.error("MessagesViewController without convId.");
        }
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
        return messageIds.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cellIdentifier = "MessagesTableViewCell"
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! MessagesTableViewCell

        let messageId = messageIds[indexPath.row]

        let messageText = KulloConnector.sharedInstance.getMessageText(messageId)
        let messageTextWithoutNewLine = messageText.stringByReplacingOccurrencesOfString("\\n+", withString: " ", options:NSStringCompareOptions.RegularExpressionSearch, range:Range<String.Index>(start: messageText.startIndex, end: messageText.endIndex))

        cell.messageImageView.image = KulloConnector.sharedInstance.getSenderAvatar(messageId, size: cell.messageImageView.frame.size);
        cell.messageImageView.showAsCircle()
        cell.messageName.text = KulloConnector.sharedInstance.getSenderName(messageId)
        cell.messageOrganization.text = KulloConnector.sharedInstance.getSenderOrganization(messageId)
        cell.messageDateLabel.text = KulloConnector.sharedInstance.getMessageSentDate(messageId).formatWithSymbolicNames()
        cell.messageTextLabel.text = messageTextWithoutNewLine

        cell.preservesSuperviewLayoutMargins = false
        cell.separatorInset = UIEdgeInsetsZero
        cell.layoutMargins = UIEdgeInsetsZero

        return cell
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
            updateDatabasisAndRefreshTable()
        }
    }

    func sessionEventMessageRemoved(convId: Int64, msgId: Int64) {
        if convId == self.convId! {
            updateDatabasisAndRefreshTable()
        }
    }

}
