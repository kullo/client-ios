/* Copyright 2015-2016 Kullo GmbH. All rights reserved. */

import UIKit

class MoreImageTableViewCell: UITableViewCell {

    @IBOutlet fileprivate var avatarImageView: UIImageView!
    
    func setAvatarImage(_ avatarImage: UIImage?) {
        avatarImageView.image = avatarImage
    }
}
