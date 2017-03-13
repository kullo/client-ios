/* Copyright 2015-2017 Kullo GmbH. All rights reserved. */

import UIKit

class MoreImageTableViewCell: UITableViewCell {

    @IBOutlet fileprivate var avatarImageView: UIImageView!

    var avatarImage: UIImage? {
        get {
            return avatarImageView.image
        }
        set {
            avatarImageView.image = newValue
        }
    }
}
