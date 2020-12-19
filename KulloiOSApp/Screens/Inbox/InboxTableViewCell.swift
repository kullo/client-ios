/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import UIKit

class ConversationTableViewCell: UITableViewCell {

    // MARK: Properties

    @IBOutlet var inboxTitleLabel: UILabel!
    @IBOutlet var inboxImageView: UIImageView!
    @IBOutlet var inboxDateLabel: UILabel!
    @IBOutlet var inboxUnreadLabel: UILabel!
}
