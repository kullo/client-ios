/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import UIKit

class MessagesTableViewCell: UITableViewCell {

    // MARK: Properties

    @IBOutlet var messageImageView: UIImageView!
    @IBOutlet var messageName: UILabel!
    @IBOutlet var messageOrganization: UILabel!

    @IBOutlet var messageDateLabel: UILabel!
    @IBOutlet var messageUnreadLabel: UILabel!
    @IBOutlet var messageTextLabel: UILabel!
}
