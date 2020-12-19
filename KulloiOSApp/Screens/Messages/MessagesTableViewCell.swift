/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import UIKit

class MessagesTableViewCell: UITableViewCell {

    // MARK: Properties

    @IBOutlet var messageImageView: UIImageView!
    @IBOutlet var messageName: UILabel!
    @IBOutlet var messageOrganization: UILabel!

    @IBOutlet var messageDateLabel: UILabel!
    @IBOutlet var messageUnreadLabel: UILabel!
    @IBOutlet var hasAttachmentsIcon: UIImageView!
    @IBOutlet var messageTextLabel: UILabel!
}
