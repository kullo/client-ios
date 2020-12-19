/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import UIKit

class MessageSearchTableViewCell: UITableViewCell {
    @IBOutlet var senderAvatar: UIImageView!
    @IBOutlet var senderName: UILabel!
    @IBOutlet var attachmentIcon: UIImageView!
    @IBOutlet var date: UILabel!
    @IBOutlet var snippet: UILabel!
}
