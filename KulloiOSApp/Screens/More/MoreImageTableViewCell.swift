/*
 * Copyright 2015–2019 Kullo GmbH
 *
 * This source code is licensed under the 3-clause BSD license. See LICENSE.txt
 * in the root directory of this source tree for details.
 */

import UIKit

class MoreImageTableViewCell: UITableViewCell {

    @IBOutlet private var avatarImageView: UIImageView!

    var avatarImage: UIImage? {
        get {
            return avatarImageView.image
        }
        set {
            avatarImageView.image = newValue
        }
    }
}
